{ pkgs, lib ? pkgs.lib, nixosModulesPath, check ? true }: with lib; let

  hostPlatform = pkgs.stdenv.hostPlatform;

  checkPlatform = any (meta.platformMatch pkgs.stdenv.hostPlatform);

  loadModule = file: { condition ? true }: {
    inherit file condition;
  };

  allModules = [
    (loadModule ./env.nix { })
    (loadModule ./lib.nix { })
    (loadModule ./exec.nix { })
    (loadModule ./config.nix { })
    (loadModule ./cipkgs.nix { })
    (loadModule ./nixpkgs.nix { })
    (loadModule ./project.nix { })
    (loadModule ./tasks.nix { })
    (loadModule ./actions.nix { })
    (loadModule ./actions-ci.nix { })
    (loadModule (nixosModulesPath + "/misc/assertions.nix") { })
    (loadModule (nixosModulesPath + "/misc/meta.nix") { })
  ];

  modules = map (getAttr "file") (filter (getAttr "condition") allModules);

  pkgsModule = { config, ... }: {
    config._module.args = {
      inherit nixosModulesPath;
      baseModules = modules;
    };
    config._module = {
      inherit check;
    };
    #config.lib = import ./lib { inherit lib; };
    config.ci.pkgs = {
      system = mkOptionDefault pkgs.system;
      config = mkOptionDefault pkgs.config;
      overlays = mkOptionDefault pkgs.overlays;
    };
  };
in modules ++ [ pkgsModule ]
