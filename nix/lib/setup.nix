{ lib, config }: with lib; {
  pname = "ci-env-setup";
  packages = builtins.attrValues config.environment.bootstrap;

  passAsFile = [ "setup" ];

  cachixUse = attrNames (filterAttrs (_: c: c.enable && c.publicKey == null) config.cache.cachix);
  inherit (config.bootstrap.packages) cachix coreutils;
  inherit (config.environment) allowRoot;
  nixSysconfDir = "${config.nix.corepkgs.config.nixSysconfDir or "/etc"}/nix";
  #inherit (config.nix) configFile;
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

    #asroot @coreutils@/bin/mkdir -p @nixSysconfDir@ &&
    #asroot @coreutils@/bin/tee -a @nixSysconfDir@/nix.conf < @configFile@ ||
    #  echo failed to configure @nixSysconfDir@/nix.conf >&2

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
