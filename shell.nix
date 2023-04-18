{ pkgs ? import <nixpkgs> { } }: with pkgs; let
  CI_CONFIG_ROOT = "\${CI_CONFIG_ROOT-${toString ./.}}";
  CI_CONFIG_FILES = "${CI_CONFIG_ROOT}/tests/*";
  gh-actions-generate = writeShellScriptBin "gh-actions-generate" ''
    for f in ${CI_CONFIG_FILES}; do
      nix run --arg config $f -f ${CI_CONFIG_ROOT} run.gh-actions-generate
    done
  '';
  test-all = writeShellScriptBin "test-all" ''
    for f in ${CI_CONFIG_FILES}; do
      if ! nix run --arg config $f -f ${CI_CONFIG_ROOT} test; then
        echo failed test $f >&2
        exit 1
      fi
    done
  '';
in mkShell {
  #CI_CONFIG = toString ./example/ci.nix
  CI_PLATFORM = "impure"; # use host's nixpkgs for more convenient testing

  nativeBuildInputs = [
    gh-actions-generate
    test-all
  ];
  shellHook = ''
    export CI_ROOT=''${CI_ROOT-${toString ./.}}
    export CI_CONFIG_ROOT=${CI_CONFIG_ROOT}
  '';
}
