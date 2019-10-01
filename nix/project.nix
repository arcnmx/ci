{ config, lib, nixosModulesPath, modulesPath, configPath, ... }: with lib; {
  options.ci = {
    config = mkOption {
      type = types.nullOr types.unspecified;
      default = null;
    };
    stage = mkOption {
      type = types.nullOr types.str;
      default = null;
      internal = true;
    };
    warn = mkOption {
      type = types.bool;
      default = false;
    };
    project = {
      name = mkOption {
        type = types.str;
        default = "ci";
      };
      exec = mkOption {
        type = types.attrsOf types.str; # TODO: or lines?
        default = { };
      };
      run = mkOption {
        type = types.attrsOf types.package;
        default = { };
      };
      stages = let
        module = types.submodule ({ name, ... }: {
          imports = [ configPath ] ++ import ./modules.nix {
            inherit (config.ci.env.bootstrap) pkgs;
            inherit lib nixosModulesPath; # pkgs
            inherit (config._module) check;
          };

          config = {
            _module.args = {
              inherit modulesPath configPath;
            };
            ci = {
              inherit config;
              stage = name;
            };
            ci.project.stages = mkForce { }; # stages only go one level deep!
          };
        });
      in mkOption {
        type = types.attrsOf module;
        default = { };
      };
    };
    export.stage = mkOption {
      type = types.attrsOf types.unspecified;
    };
  };
  config = {
    ci = {
      export.stage = mapAttrs (_: s: s.ci.export) config.ci.project.stages;
    };
    lib.ci = {
      inherit (import ./lib/scope.nix { }) nixPathImport;
    };
  };
}
