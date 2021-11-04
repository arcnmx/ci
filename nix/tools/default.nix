{
  pkgs ? import <nixpkgs> { }
}: let
  derivations = {
    ci-query = { substituteAll, runtimeShell, nix }: substituteAll {
      name = "ci-query";
      dir = "bin";
      src = ./query.sh;
      isExecutable = true;
      inherit runtimeShell nix;
    };
    ci-dirty = { substituteAll, runtimeShell, coreutils, nix }: substituteAll {
      name = "ci-dirty";
      dir = "bin";
      src = ./dirty.sh;
      isExecutable = true;
      inherit runtimeShell coreutils nix;
    };
  };
in with derivations; {
  ci-query = pkgs.callPackage ci-query { };
  ci-dirty = pkgs.callPackage ci-dirty { };
}
