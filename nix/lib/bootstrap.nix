{ lib, config }: with lib; {
  pname = "ci-env-bootstrap";
  packages = builtins.attrValues config.ci.env.environment.bootstrap;

  passAsFile = [ "setup" "run" ];

  cachixUse = attrNames (filterAttrs (_: v: v.publicKey == null) config.ci.env.cache.cachix);
  inherit (config.ci.env.bootstrap.nix.corepkgs.config) nixSysconfDir;
  inherit (config.ci.env.bootstrap.nix) configFile;
  inherit (config.ci.env.bootstrap.packages) cachix coreutils;
  inherit (config.ci.env.bootstrap) allowRoot;
  setup = ''
    #!@runtimeShell@
    set -eu

    source @out@/@prefix@/env
    ci_env_impure

    asroot() {
      if [[ ! -w @nixSysconfDir@ && -n "@allowRoot@" ]]; then
        sudo @coreutils@/bin/env PATH="$PATH" NIX_SSL_CERT_FILE=$NIX_SSL_CERT_FILE "$@"
      else
        "$@"
      fi
    }
    asroot @coreutils@/bin/mkdir -p @nixSysconfDir@/nix &&
    asroot @coreutils@/bin/tee -a @nixSysconfDir@/nix/nix.conf < @configFile@ ||
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

  runtimeDrv = builtins.unsafeDiscardStringContext config.ci.env.packages.test.drvPath;
  passthru = {
    ciEnv = config.ci.env.environment.test;
  };

  command = ''
    substituteBin $setupPath ci-setup
    substituteBin $runPath ci-run
  '';
}
