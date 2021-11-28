{ lib }: let
  inherit (lib) moduleIndex;
in moduleIndex {
  modules = {
    # GitHub Actions workflow configuration
    actions = ./actions.nix;

    # Apply the CI config to GitHub Actions
    actions-ci = ./actions-ci.nix;

    # Entry points, impure configuration, and nix bootstrapping
    bootstrap = ./bootstrap.nix;

    # Documentation generation
    documentation = ./documentation.nix;
  };
}
