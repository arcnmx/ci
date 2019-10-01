{ pkgs ? import <nixpkgs> { }, config ? throw "missing config" }@args: import ./nix {
  ${if (builtins.tryEval pkgs).success && pkgs != null then "pkgs" else null} = pkgs;
  configuration = config;
}
