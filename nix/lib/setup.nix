{ lib, config }: with lib; {
  pname = "ci-env-setup";
  packages = builtins.attrValues config.environment.bootstrap;

  passAsFile = [ "setup" ];

  cachixUse = attrNames (filterAttrs (_: v: v.publicKey == null) config.cache.cachix);
  inherit (config.bootstrap.packages) cachix coreutils;
  inherit (config.environment) allowRoot;
  inherit (config.nix.corepkgs.config) nixSysconfDir;
  inherit (config.nix) configFile;
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
      echo Setting up cache $cachixCache... >&2
      asroot @cachix@/bin/cachix use $cachixCache ||
        echo failed to add cache >&2
    done
  '';

  command = ''
    substituteBin $setupPath ci-setup
  '';
}
