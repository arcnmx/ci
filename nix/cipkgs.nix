{ config, pkgs, lib, ... }: with lib; let
  cfg = config.ci.pkgs;
  cipkgs = import ./lib/cipkgs.nix;
in {
  options.ci.pkgs = {
    path = mkOption {
      type = types.path;
      default = cfg.pathFor.${builtins.nixVersion} or cfg.pathFor."19.03";
    };
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/impure.nix
    pkgs = mkOption {
      type = types.unspecified;
      default = import cfg.path {
        inherit (cfg) config overlays system;
      };
    };
    overlays = mkOption {
      type = types.listOf types.unspecified;
      default = [ ];
    };
    config = mkOption {
      type = types.attrsOf types.unspecified;
    };
    system = mkOption {
      type = types.str;
    };
    pathFor = mkOption {
      type = types.attrsOf types.unspecified;
      internal = true;
    };
  };
  config.ci.pkgs = {
    overlays = [ (import ./overlay.nix) (import ./lib/overlay.nix { inherit config; }) ];
    config = {
      checkMetaRecursively = true;
    };
    pathFor = mapAttrs (_: builtins.fetchTarball) cipkgs.nixpkgsFor;
  };
}
