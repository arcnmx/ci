{ config, lib, channels, configPath, ... }: with lib; let
  cfg = config.ci.gh-actions;
  action = name: if ! hasPrefix "http" config.ci.url
    then {
      path = "${config.ci.url}/actions/${name}";
    } else {
      owner = "arcnmx";
      repo = "ci";
      version = config.ci.version;
      path = "actions/${name}";
    };
  ciJob = {
    id
  , name ? null
  , platform ? systems.elaborate config.channels.nixpkgs.args.system
  , step ? { }
  , env ? { }
  }: { ${id} = {
    /* TODO: additional/manual setting overrides
    - Like say runs-on for testing different OS versions
    - Also ability to matrix without actually creating a whole new jobId? because...
      - it can be useful to test on old and new macOS versions for ex
      - ... but when running locally or on platforms that can't differentiate, there's no point in building the jobId multiple times!
    */
    # TODO: needs (jobId deps)
    # TODO: if conditionals

    runs-on = if platform.isLinux then "ubuntu-latest"
      else if platform.isDarwin then "macOS-latest"
      else throw "unknown GitHub Actions platform for ${platform.system}";
    inherit env;
    step = step // {
      checkout = {
        order = 10;
        name = "git clone";
        uses = {
          owner = "actions";
          repo = "checkout";
          version = "v1";
        };
        "with" = cfg.checkoutOptions;
      } // step.checkout or {};
      nix-install = {
        order = 100;
        name = "nix install";
        uses = action "nix/install";
      } // step.nix-install or {};
    };
  } // optionalAttrs (name != null) {
    inherit name;
  }; };
in {
  options.ci.gh-actions = {
    enable = mkEnableOption "GitHub Actions CI";
    checkoutOptions = mkOption {
      type = types.attrsOf types.unspecified;
      defaultText = ''{ submodules = true; }'';
    };
    name = mkOption {
      type = types.str;
      default = foldl' (s: i:
        if i == null || i == s then s
        else if s == null then i
        else "${s}-${i}") null [ config.name config.stageId config.jobId ];
    };
    path = mkOption {
      type = types.nullOr types.str;
      default = ".github/workflows/${config.name}.yml";
    };
    export = mkOption {
      # export runtime test environment to the host
      type = types.bool;
      default = false;
    };
    emit = mkOption {
      type = types.bool;
      default = config.jobs == { };
    };
  };
  options.export.gh-actions = {
    configFile = mkOption {
      type = types.package;
    };
  };
  config.ci.gh-actions = {
    checkoutOptions = {
      submodules = mkOptionDefault true;
    };
  };
  config.export.gh-actions = {
    inherit (config.gh-actions) configFile;
  };
  config.gh-actions = mkIf config.ci.gh-actions.enable {
    enable = true;
    env = mapAttrs (_: mkDefault) {
      CI_ALLOW_ROOT = "1";
      CI_CLOSE_STDIN = "1"; # TODO: is this necessary on actions or just azure pipelines?
      CI_PLATFORM = "gh-actions";
      CI_CONFIG = config.ci.configPath;
    };
    # TODO: on push/pull or on check? what is check?
    name = config.name;
    jobs = mkMerge [
      (mkIf cfg.emit (ciJob {
        inherit (config) id;
        name = mkDefault cfg.name;
        step = {
          ci-setup = mkIf (cfg.export || any (c: c.enable && c.publicKey == null) (attrValues config.cache.cachix)) {
            order = 200;
            name = "nix setup";
            uses = action "nix/run";
            "with" = {
              attrs = "ci.${config.exportAttrDot}run.${if cfg.export then "bootstrap" else "setup"}";
              quiet = false;
            };
            /*uses = action "internal/ci-setup";
            "with" = {
              job = toString config.jobId;
              stage = toString config.stageId;
              inherit (config.ci) configPath;
            };*/
            env.CACHIX_SIGNING_KEY = "\${{ secrets.CACHIX_SIGNING_KEY }}";
          };
          ci-test = {
            name = "nix test";
            uses = action "nix/run";
            "with" = {
              attrs = "ci.${config.exportAttrDot}run.test";
              quiet = false;
            };
            /*uses = action "internal/ci-build";
            "with" = {
              job = toString config.jobId;
              stage = toString config.stageId;
              inherit (config.ci) configPath;
            };*/
            env.CACHIX_SIGNING_KEY = "\${{ secrets.CACHIX_SIGNING_KEY }}";
          };
        };
      }))
      (filterAttrs (_: v: v != null) (mapAttrs (k: config:
        config.gh-actions.jobs.${config.id} or null
      ) config.jobs))
      (filterAttrs (_: v: v != null) (mapAttrs (k: config:
        config.gh-actions.jobs.${config.id} or null
      ) config.stages))
      (mkIf (config.jobId == null && config.ci.gh-actions.path != null) (ciJob {
        id = "${config.id}-check";
        name = mkDefault "${cfg.name} check";
        step = {
          # alternatively, run gh-actions-generate and check for unclean git repo instead?
          ci-action-build = {
            name = "nix build ci.gh-actions.configFile";
            uses = action "nix/build";
            "with" = {
              attrs = "ci.gh-actions.configFile";
              out-link = ".ci/workflow.yml";
            };
          };
          ci-action-compare = {
            name = "gh-actions compare";
            uses = action "nix/run";
            "with" = {
              attrs = "nixpkgs.diffutils";
              command = "diff";
              args = "-u ${config.ci.gh-actions.path} .ci/workflow.yml";
            };
          };
        };
      }))
    ];
  };
  config.export.run.gh-actions-generate = mkIf (cfg.enable && cfg.path != null) (config.lib.ci.nixRunWrapper "gh-actions-generate" (channels.cipkgs.writeShellScriptBin "gh-actions-generate" ''
    cp --no-preserve=mode,ownership,timestamps ${config.export.gh-actions.configFile} ${cfg.path}
  ''));
}
