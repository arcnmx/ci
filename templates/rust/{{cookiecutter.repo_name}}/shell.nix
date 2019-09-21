{ pkgs ? import <nixpkgs> { } }: let
  ci = import https://github.com/arcnmx/ci/archive/master.tar.gz ./ci/config.nix;
in ci.shell
