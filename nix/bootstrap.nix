{ env, runtimeEnv }@args: with env; envBuilder {
  pname = "ci-env-bootstrap";
  packages = builtins.attrValues packagesBase;

  passAsFile = [ "setup" "run" ];

  cachixUse = config.cache.cachixUse;
  inherit (nixConfig) nixSysconfDir;
  allowRoot = config.allowRoot or "";
  inherit nixConfigFile cachix coreutils;
  setup = ''
    #!@runtimeShell@
    set -eu

    source @out@/@prefix@/env
    ci_env_impure

    asroot() {
      if [[ ! -w @nixSysconfDir@ && -n "@allowRoot@" ]]; then
        # optionally bring in sudo from cipkgs? setuid is complicated though
        sudo @coreutils@/bin/env PATH="$PATH" NIX_SSL_CERT_FILE=$NIX_SSL_CERT_FILE "$@"
      else
        "$@"
      fi
    }
    asroot @coreutils@/bin/mkdir -p @nixSysconfDir@/nix &&
    asroot @coreutils@/bin/tee -a @nixSysconfDir@/nix/nix.conf < @nixConfigFile@ ||
      echo failed to configure @nixSysconfDir@/nix/nix.conf >&2
    for cachixCache in @cachixUse@; do
      asroot @cachix@/bin/cachix use $cachixCache ||
        echo failed to add cache $cachixCache >&2
    done

    BUILD_ARGS=(@runtimeDrv@)
    if [[ -n ''${CI_ENV-} ]]; then
      BUILD_ARGS+=(-o $CI_ENV)
    fi
    exec @nix@/bin/nix-build "''${BUILD_ARGS[@]}"
  '';

  run = ''
    #!@runtimeShell@
    set -eu

    exec @nix@/bin/nix run $(@nix@/bin/nix-build --no-out-link @runtimeDrv@) "$@"
  '';

  runtimeDrv = builtins.unsafeDiscardStringContext runtimeEnv.drvPath;
  passthru = {
    ciEnv = runtimeEnv;
  };
}) ''
  substituteBin $setupPath ci-setup
  substituteBin $runPath ci-run

  substituteAll $runPath $out/$prefix/run
  ln -s $out/$prefix/run $out/bin/ci-run
  chmod +x $out/$prefix/run
''
