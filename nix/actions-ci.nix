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
  subjobs = configs: (filterAttrs (_: v: v != null) (mapAttrs
    (k: configs: let
      job = configs.gh-actions.jobs.${configs.id} or null;
      job' = job // {
        env = filterAttrs (k: v: config.gh-actions.env.${k} or null != v) (
          configs.gh-actions.env // job.env or {}
        );
      };
    in if job == null then null else job') configs
  ));
  ciJob = {
    id
  , name ? null
  , platform ? systems.elaborate config.channels.nixpkgs.args.system
  , step ? { }
  , steps ? [ ]
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
      else if platform.isDarwin then "macos-10.15"
      else throw "unknown GitHub Actions platform for ${platform.system}";
    inherit env;
    step = step // {
      checkout = {
        order = 10;
        name = "git clone";
        uses = {
          owner = "actions";
          repo = "checkout";
          version = cfg.checkoutVersion;
        };
        "with" = cfg.checkoutOptions;
      } // step.checkout or {};
      nix-install = {
        order = 100;
        name = "nix install";
        uses = action "nix/install";
      } // step.nix-install or {};
    };
    inherit steps;
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
    checkoutVersion = mkOption {
      type = types.str;
      default = "v1";
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
      #CI_CLOSE_STDIN = "1"; # TODO: is this necessary on actions or just azure pipelines?
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
          };
        };
        steps = [ { # TODO: nix/build with export-path instead to avoid repeating evaluation
          id = "ci-dirty";
          name = "nix test dirty";
          uses = action "nix/run";
          "with" = {
            attrs = "ci.${config.exportAttrDot}run.test";
            command = "ci-build-dirty";
            stdout = "\${{ runner.temp }}/ci.build.dirty";
            quiet = false;
          };
        } {
          id = "ci-test";
          name = "nix test build";
          uses = action "nix/run";
          "with" = {
            attrs = "ci.${config.exportAttrDot}run.test";
            command = "ci-build-realise";
            stdin = "\${{ runner.temp }}/ci.build.dirty";
            quiet = false;
            ignore-exit-code = true;
          };
        } {
          id = "ci-summary";
          name = "nix test results";
          uses = action "nix/run";
          "with" = {
            attrs = "ci.${config.exportAttrDot}run.test";
            command = "ci-build-summarise";
            stdin = "\${{ runner.temp }}/ci.build.dirty";
            stdout = "\${{ runner.temp }}/ci.build.cache";
            quiet = false;
          };
          env.CI_EXIT_CODE = "\${{ steps.ci-test.outputs.exit-code }}";
        } {
          id = "ci-cache";
          name = "nix test cache";
          uses = action "nix/run";
          "with" = {
            attrs = "ci.${config.exportAttrDot}run.test";
            command = "ci-build-cache";
            stdin = "\${{ runner.temp }}/ci.build.cache";
            quiet = false;
          };
          "if" = "always()";
          env.CACHIX_SIGNING_KEY = "\${{ secrets.CACHIX_SIGNING_KEY }}";
        } ];
      }))
      (subjobs config.jobs)
      (subjobs config.stages)
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
  config.export.run.gh-actions-generate = let
    gen = (channels.cipkgs.writeShellScriptBin "gh-actions-generate" ''
      install -Dm0644 ${config.export.gh-actions.configFile} ${cfg.path}
    '').overrideAttrs (old: {
      meta = old.meta or {} // {
        description = "generate or update the GitHub Actions workflow file";
      };
    });
  in mkIf (cfg.enable && cfg.path != null) (config.lib.ci.nixRunWrapper "gh-actions-generate" gen);
}
