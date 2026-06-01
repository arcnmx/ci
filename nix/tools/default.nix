{
  pkgs ? import <nixpkgs> { }
}: let
  derivations = {
    ci-query = { replaceVarsWith, runtimeShell, nix }: replaceVarsWith {
      name = "ci-query";
      dir = "bin";
      src = ./query.sh;
      isExecutable = true;
      replacements = {
        inherit runtimeShell nix;
      };
    };
    ci-dirty = { replaceVarsWith, runtimeShell, coreutils, nix }: replaceVarsWith {
      name = "ci-dirty";
      dir = "bin";
      src = ./dirty.sh;
      isExecutable = true;
      replacements = {
        inherit runtimeShell coreutils nix;
      };
    };
  };
in with derivations; {
  ci-query = pkgs.callPackage ci-query { };
  ci-dirty = pkgs.callPackage ci-dirty { };
}
