{ pkgs ? import <nixpkgs> { } }:
  (pkgs.extend (import ./overlay.nix)).{{cookiecutter.project_slug}}
