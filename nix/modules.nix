{ pkgs ? null, check ? true }: let
  libPath = import ./lib/lib.nix;
  module = { config, lib, ... }: with lib; {
    imports = [
      (libPath + "/nixos/modules/misc/assertions.nix")
      (libPath + "/nixos/modules/misc/meta.nix")
    ];

    config._module = {
      inherit check;
    };
    #config.lib = import ./lib { inherit lib; };
    config.nixpkgs = mkIf (pkgs != null) {
      args = {
        localSystem = config.lib.ci.mkOptionDefault1 pkgs.buildPlatform.system;
        crossSystem = mkIf (pkgs.buildPlatform != pkgs.hostPlatform) (config.lib.ci.mkOptionDefault1 pkgs.hostPlatform.system);
        config = mapAttrs (_: config.lib.ci.mkOptionDefault1) pkgs.config or {};
        overlays = pkgs.overlays or [];
        crossOverlays = pkgs.crossOverlays or [];
      };
      path = config.lib.ci.mkOptionDefault2 (toString pkgs.path);
    };
  };
in [
  ./env.nix
  ./lib.nix
  ./exec.nix
  ./config.nix
  ./project.nix
  ./tasks.nix
  ./actions.nix
  ./actions-ci.nix
  module
]
