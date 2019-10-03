{ lib, runCommandNoCC, hostPlatform, cacert, config }: with lib; let
  cfg = config.ci.env;
  glibcLocales = listToAttrs (map (glibc:
    lib.nameValuePair (replaceStrings [ "." ] [ "_" ] glibc.version) "${glibc}/lib/locale/locale-archive"
  ) (cfg.glibcLocales or [ ]));
in makeOverridable ({ pname, packages ? [], command ? "", passAsFile ? [], ... }@args: runCommandNoCC pname ({
  inherit cacert;
  inherit (cfg) prefix;
  inherit (cfg.bootstrap) runtimeShell;
  inherit (cfg.bootstrap.packages) nix;

  passAsFile = [ "source" "env" "rc" "shellBin" ] ++ passAsFile;

  packages = map getBin packages;
  ciRoot = toString ../..;
  nixPathStr = builtins.concatStringsSep ":" (builtins.attrValues (builtins.mapAttrs (k: v: "${k}=${v}") cfg.nixPath));
  glibcLocaleVars = optionals hostPlatform.isLinux (mapAttrsToList (name: path:
    "LOCALE_ARCHIVE_${name}=${path}"
  ) glibcLocales);
  env = ''
    ci_env_host() {
      export PATH=$HOST_PATH
    }

    ci_env_nix() {
      export PATH=$CI_PATH
    }

    ci_env_impure() {
      export PATH=$CI_PATH:$HOST_PATH
    }

    if [[ -n ''${CI_PATH-} ]]; then return; fi

    if [[ $- != *i* ]]; then
      # non-interactive shells should bail on any error
      set -euo pipefail
    fi
    ${optionalString cfg.bootstrap.closeStdin "exec 0<&-"}

    export NIX_PATH=@nixPathStr@
    export NIX_PREFIX=@nix@
    export HOST_PATH=$PATH
    export CI_PATH=@out@/bin
    export CI_ROOT=@ciRoot@
    export NIX_SSL_CERT_FILE=@cacert@/etc/ssl/certs/ca-bundle.crt
    export TERMINFO_DIRS=''${TERMINFO_DIRS-}:/usr/share/terminfo:@out@/share/terminal
    for locale in @glibcLocaleVars@; do
      export $locale
    done
  '';

  source = ''
    source @out@/@prefix@/env

    ci_env_nix
  '';

  rc = ''
    ci_rc_env() {
      local CI_RCFILE
      if [[ -n ''${BASH_VERSION-} ]]; then
        CI_RCFILE=''${HOME-/homeless}/.bashrc
      fi
      if [[ -e ''${CI_RCFILE-} && -n ''${CI_IMPURE-} ]]; then
        source $CI_RCFILE
      fi

      source @out@/@prefix@/source
      if [[ -n ''${CI_IMPURE-} ]]; then
        ci_env_impure
      fi
    }

    ci_rc_env
  '';

  shellBin = ''
    #!@runtimeShell@

    # TODO: check for zsh or other shells
    # TODO: assumption here that $runtimeShell is bash (accepts --rcfile)

    exec @runtimeShell@ --rcfile @out@/@prefix@/rc "$@"
  '';
} // builtins.removeAttrs args ["pname" "command" "passAsFile" "packages"]) ''
  install -d $out/$prefix $out/bin

  for pkg in $packages; do
    cp --no-preserve=mode -rsf $pkg/* $out/
  done

  substituteBin() {
    substituteAll $1 $out/bin/$2
    chmod +x $out/bin/$2
  }

  substituteAll $sourcePath $out/$prefix/source
  substituteAll $envPath $out/$prefix/env
  substituteAll $rcPath $out/$prefix/rc
  substituteBin $shellBinPath ci-shell

  ${command}
'')
