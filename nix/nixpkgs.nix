{ config, lib, pkgs, modulesPath, ... }: with lib; {
  options.nixpkgs = {
    config = mkOption {
      type = types.attrs;
      example = { allowBroken = true; };
    };

    overlays = mkOption {
      type = types.listOf types.unspecified;
    };

    system = mkOption {
      type = types.str;
      example = "i686-linux";
      internal = true;
    };
  };
  config.nixpkgs.system = config.ci.pkgs.system;
  config.nixpkgs.config = config.ci.pkgs.config;
  config.nixpkgs.overlays = config.ci.pkgs.overlays;
}
