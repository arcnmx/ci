{ lib, config }: with lib; {
  pname = "ci-env-bootstrap";
  packages = builtins.attrValues config.environment.bootstrap;

  passAsFile = [ "setup" "build" "run" ];

  setup = ''
    #!@runtimeShell@
    set -eu

    @setupEnv@/bin/ci-setup

    @out@/bin/ci-build
  '';

  build = ''
    #!@runtimeShell@
    set -eu

    source @out@/@prefix@/env
    ci_env_impure

    BUILD_ARGS=(-E "import @runtimeDrv@")
    if [[ -n ''${CI_ENV-} ]]; then
      BUILD_ARGS+=(-o $CI_ENV)
    fi
    @nix@/bin/nix-build "''${BUILD_ARGS[@]}"

    case "''${CI_PLATFORM-}" in
      gh-actions)
        SOURCE=@runtimeOut@/@prefix@/source
        if [[ -v GITHUB_ENV ]]; then
          echo "BASH_ENV=$SOURCE" >> $GITHUB_ENV
        else
          echo "::set-env name=BASH_ENV::$SOURCE" >&2
        fi
        ;;
    esac
  '';

  run = ''
    #!@runtimeShell@
    set -eu

    exec @nix@/bin/nix run $(@nix@/bin/nix-build --no-out-link @runtimeDrv@) "$@"
  '';

  runtimeDrv = builtins.unsafeDiscardStringContext config.export.env.test.drvPath;
  runtimeOut = builtins.unsafeDiscardStringContext config.export.env.test.outPath;
  setupEnv = config.export.env.setup;
  passthru = {
    ciEnv = config.export.env.test;
  };

  command = ''
    substituteBin $buildPath ci-build
    substituteBin $setupPath ci-setup
    substituteBin $runPath ci-run
  '';
}
