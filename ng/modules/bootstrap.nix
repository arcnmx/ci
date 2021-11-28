{ config, lib, ... }: let
  inherit (builtin) mapAttrs;
  inherit (lib)
    mkOption mkOptionDefault
    versionAtLeast;
  ty = lib.types;
in {
  #### nix config generator
  options.nix = mkOption {
    type = let
      nixModule = {
        options = {
          version = mkOption {
            type = ty.str;
            default = builtins.nixVersion;
          };
        };
      };
    in types.submodule [
      ./nix.nix
    ];
  };
  config.nix = let
    cfg = config.nix;
  in {
    settings = mapAttrs (_: mkOptionDefault) {
      cores = 0;
      max-jobs = 8;
      #http2 = false;
      max-silent-time = 60 * 30;
      fsync-metadata = false;
      use-sqlite-wal = true;
    } // {
      experimental-features = mkIf (versionAtLeast cfg.version "2.4") (mkOptionDefault [
        "nix-command" "flakes" "ca-derivations" "recursive-nix"
      ]);
    };
  };

  #### file generation (generic mechanism for keeping files in repo up-to-date; includes workflow yaml files, READMEs, docs, etc). out-of date files can be warnings, fixes, or even automatic pushes to fix them
  #### meta-flake generator (if needed?)
  #### impure data transport (env vars -> pure input -> flake eval)
}
