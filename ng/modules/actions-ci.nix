{ config, lib, ... }: let
  inherit (lib) mkOption mkOptionDefault;
  inherit (builtins) mapAttrs;
  ty = lib.types;
  actionModule = { config, options, ... }: {
    options = {
      ci.action = mkOption {
        type = ty.str;
      };
    };
    config = let
      isRelease = hasPrefix "http" todo.url; # internal CI tests will instead refer to the action repo by relative path
      action = optionalString (!isRelease) "${url}/" + "actions/${config.ci.action}";
    in {
      path = mkIf options.ci.action.isDefined action;
      owner = mkIf (options.ci.action.isDefined && isRelease) "arcnmx";
      repo = mkIf (options.ci.action.isDefined && isRelease) "ci";
      version = mkIf (options.ci.action.isDefined && isRelease) todo.version;
    };
  };
  stepModule = { config, ... }: {
    options = {
      uses = mkOption {
        type = ty.nullOr (ty.submodule actionModule);
      };
    };
  };
  jobModule = { config, workflow, ... }: {
    options = {
      step = mkOption {
        type = ty.attrsOf (ty.submodule stepModule);
      };
    };
    config = {
      step = {
        checkout = {
          order = mkDefault 10;
          name = mkDefault "git clone";
          uses = mapAttrs (_: mkDefault) {
            owner = "actions";
            repo = "checkout";
            version = workflow.checkout.version;
          };
          "with" = mapAttrs (_: mkOptionDefault) workflow.checkout.options;
        };
        nix-install = {
          order = mkDefault 100;
          name = mkDefault "nix install";
          uses.ci.action = "nix/install";
          "with".version = mkOptionDefault workflow.nix.version;
        };
        nix-config-bootstrap = {
          order = mkDefault 125;
          name = mkDefault "nix config (bootstrap)";
          uses.ci.action = "nix/eval";
          "with" = {
            weh = throw "TODO";
            stdout = "/etc/nix/nix.conf";
          };
        };
        nix-config = {
          order = mkDefault 125;
          name = mkDefault "nix config";
          uses.ci.action = "nix/eval";
          "with" = {
            weh = throw "TODO";
            stdout = "/etc/nix/nix.conf";
          };
        };
      };
    };
  };
  workflowModule = { name, config, ... }: {
    options = {
      enable = mkEnableOption "GitHub Actions workflow" // {
        default = true;
      };
      checkout = {
        version = mkOption {
          type = ty.str;
          default = "v2";
        };
        options = mkOption {
          type = ty.attrsOf (ty.oneOf [ ty.int ty.bool ty.str ]);
          defaultText = ''{ submodules = true; }'';
        };
      };
      nix.version = mkOption {
        type = ty.oneOf [ (ty.enum [ "latest" ]) ty.str ];
        default = "latest";
      };
      path = mkOption {
        type = ty.str;
        default = ".github/workflows/${config.name}.yml";
      };
      jobs = mkOption {
        type = ty.submodule [
          jobModule
          {
            config._module.args.workflow = config;
          }
        ];
      };
    };
    config = {
      name = mkOptionDefault name;
      checkout.options.submodules = true;
    };
  };
in {
  options.actions = {
    enable = mkEnableOption "GitHub Actions";
    workflows = mkOption {
      type = ty.attrsOf (ty.submodule [
        workflowModule
        ./actions.nix
      ]);
  };
}
