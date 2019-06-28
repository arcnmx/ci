{
  pkgs ? import <nixpkgs> { }
}: let
  derivations = {
    ci-query = { substituteAll, runtimeShell, yq, nix }: substituteAll {
      name = "ci-query";
      dir = "bin";
      src = ./query.sh;
      isExecutable = true;
      inherit runtimeShell yq nix;
    };
    ci-dirty = { substituteAll, runtimeShell, coreutils, jq }: substituteAll {
      name = "ci-dirty";
      dir = "bin";
      src = ./dirty.sh;
      isExecutable = true;
      inherit runtimeShell coreutils jq;
    };
  };
in with derivations; {
  ci-query = pkgs.callPackage ci-query { };
  ci-dirty = pkgs.callPackage ci-dirty { };
}
