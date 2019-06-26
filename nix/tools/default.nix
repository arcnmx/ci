{
  pkgs ? import <nixpkgs> { }
}: let
  derivations = {
    ci-query = { substituteAll, runtimeShell, yq, nix }: substituteAll {
      name = "ci-query";
      dir = "bin";
      src = ./query.sh;
      inherit runtimeShell yq nix;
    };
    ci-dirty = { substituteAll, runtimeShell, jq }: substituteAll {
      name = "ci-dirty";
      dir = "bin";
      src = ./dirty.sh;
      inherit runtimeShell jq;
    };
  };
in with derivations; {
  ci-query = pkgs.callPackage ci-query { };
  ci-dirty = pkgs.callPackage ci-dirty { };
}
