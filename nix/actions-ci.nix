{ config, lib, configPath, ... }: with lib; let
  cfg = config.ci.gh-actions;
  stagePrefix = optionalString (config.ci.stage != null) "stage.${config.ci.stage}.";
  platform = systems.elaborate { inherit (config.ci.pkgs) system; };
  action = name: if ! hasPrefix "http" config.ci.url
    then {
      path = "${config.ci.url}/actions/${name}";
    } else {
      owner = "arcnmx";
      repo = "ci";
      version = config.ci.version;
      path = "actions/${name}";
    };
in {
  options.ci.gh-actions = {
    enable = mkEnableOption "GitHub Actions CI";
    checkoutOptions = mkOption {
      type = types.attrsOf types.unspecified;
      defaultText = ''{ submodules = true; }'';
    };
    id = mkOption {
      type = types.str;
      default = if config.ci.stage != null then config.ci.stage else "ci";
    };
    name = mkOption {
      type = types.str;
      default = if config.ci.stage != null then config.ci.stage else config.ci.project.name;
    };
    path = mkOption {
      type = types.nullOr types.str;
      default = ".github/workflows/${config.ci.project.name}.yml";
    };
    emit = mkOption {
      type = types.bool;
      default = config.ci.project.stages == { };
    };
  };
  options.ci.export.gh-actions = {
    configFile = mkOption {
      type = types.package;
    };
  };
  config.ci.gh-actions = {
    checkoutOptions = {
      submodules = mkOptionDefault true;
    };
  };
  config.ci.export.gh-actions = {
    inherit (config.gh-actions) configFile;
  };
  config.gh-actions = mkIf config.ci.gh-actions.enable {
    enable = true;
    name = mkOptionDefault config.ci.project.name;
    # TODO: on push/pull or on check? what is check?
    jobs = optionalAttrs cfg.emit { ${cfg.id} = {
      name = if config.ci.stage != null then config.ci.stage else config.ci.project.name;
      /* TODO: additional/manual setting overrides
      - Like say runs-on for testing different OS versions
      - Also ability to matrix without actually creating a whole new stage? because...
        - it can be useful to test on old and new macOS versions for ex
        - ... but when running locally or on platforms that can't differentiate, there's no point in building the stage multiple times!
      */
      # TODO: needs (stage deps)
      # TODO: if conditionals

      runs-on = if platform.isLinux then "ubuntu-latest"
        else if platform.isDarwin then "macOS-latest"
        else throw "unknown GitHub Actions platform for ${platform.system}";
      env = {
        CI_ALLOW_ROOT = "1";
        CI_CLOSE_STDIN = "1"; # TODO: is this necessary on actions or just azure pipelines?
        CI_PLATFORM = "gh-actions";
        CACHIX_SIGNING_KEY = "\${{ secrets.CACHIX_SIGNING_KEY }}";
      };
      steps = mkMerge [ (mkBefore [ {
        id = "ci-clone";
        name = "git clone";
        uses = {
          owner = "actions";
          repo = "checkout";
          version = "v1";
        };
        "with" = cfg.checkoutOptions;
      } {
        id = "ci-nix-install";
        name = "nix install";
        uses = action "nix/install";
      } {
        id = "ci-setup";
        name = "nix build ci-env";
        uses = action "internal/ci-setup";
        "with" = {
          stage = toString config.ci.stage;
          inherit (config.ci) configPath;
          inherit (config.ci.env) prefix;
        };
      } ]) [ {
        id = "ci-build";
        name = "nix test";
        uses = action "internal/ci-build";
        "with" = {
          stage = toString config.ci.stage;
          inherit (config.ci) configPath;
          inherit (config.ci.env) prefix;
        };
      } ] ];
    }; } // filterAttrs (_: v: v != null) (mapAttrs (k: config:
      config.gh-actions.jobs.${config.ci.gh-actions.id} or null
    ) config.ci.project.stages) // optionalAttrs (config.ci.stage == null && config.ci.gh-actions.path != null) {
      check = {
        steps = mkMerge [ (mkBefore [ {
          id = "ci-clone";
          name = "git clone";
          uses = {
            owner = "actions";
            repo = "checkout";
            version = "v1";
          };
          "with" = cfg.checkoutOptions;
        } {
          id = "ci-nix-install";
          name = "nix install";
          uses = action "nix/install";
        } ]) [ {
          id = "ci-action-build";
          name = "nix build ci.gh-actions.configFile";
          uses = action "nix/build";
          "with" = {
            options = "--arg config ${config.ci.configPath}";
            attrs = "ci.gh-actions.configFile";
            out-link = ".ci/workflow.yml";
          };
        } {
          id = "ci-action-compare";
          name = "gh-actions compare";
          uses = action "nix/run";
          "with" = {
            attrs = "nixpkgs.diffutils";
            command = "diff";
            args = "-u ${config.ci.gh-actions.path} .ci/workflow.yml";
          };
        } ] ];
      };
    };
  };
  config.ci.export.run.gh-actions-generate = mkIf (cfg.enable && cfg.path != null) (config.ci.env.bootstrap.pkgs.writeShellScriptBin "run" ''
    cp --no-preserve=mode,ownership,timestamps ${config.ci.export.gh-actions.configFile} ${cfg.path}
  '');
}
