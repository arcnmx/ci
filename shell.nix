{ pkgs ? import <nixpkgs> { } }: with pkgs; mkShell {
  CI_ROOT = toString ./.;
  CI_CONFIG_ROOT = toString ./.;
  #CI_CONFIG = toString ./example/ci.nix
  CI_PLATFORM = "impure"; # use host's nixpkgs for more convenient testing

  shellHook = ''
    export NIX_PATH="ci=$CI_ROOT:$NIX_PATH"
    CI_CONFIG_FILES=($CI_CONFIG_ROOT/tests/* $CI_CONFIG_ROOT/examples/ci.nix)

    gh-actions-generate() {
      for f in "''${CI_CONFIG_FILES[@]}"; do
        nix run --arg config "$f" ci.run.gh-actions-generate
      done
    }

    test-all() {
      for f in "''${CI_CONFIG_FILES[@]}"; do
        nix run --arg config "$f" ci.test || break
      done
    }
  '';
}
