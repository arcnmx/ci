{ pkgs, check ? true }: let
  libPath = import ./lib/lib.nix;
  module = { config, lib, ... }: with lib; {
    imports = [
      (libPath + "/modules/assertions.nix")
      (libPath + "/modules/meta.nix")
    ];

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
in [
  ./env.nix
  ./lib.nix
  ./exec.nix
  ./config.nix
  ./cipkgs.nix
  ./nixpkgs.nix
  ./project.nix
  ./tasks.nix
  ./actions.nix
  ./actions-ci.nix
  module
]
