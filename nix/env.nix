{ cipkgs, nixPath, config }: with cipkgs; rec {
  prefix = "ci";
  nixConfig = import <nix/config.nix>;
  nixConfigPaths = builtins.mapAttrs (k: v: builtins.storePath (/. + v + "/../..")) {
    # nix appears to expect these to be available in PATH
    inherit (nixConfig) tar gzip xz bzip2 shell;
  };
  inherit (nixConfigPaths) tar gzip bzip2 xz shell;
  coreutils = builtins.storePath (/. + nixConfig.coreutils + "/..");
  nix = builtins.storePath (/. + nixConfig.nixPrefix);
  runtimeShell = builtins.storePath nixConfig.shell;
  cachix = if config.cache.cachixUse != [] || config.cache.cachixKeys != {}
    then lib.getBin cipkgs.cachix
    else null;
  tools = import ./tools {
    pkgs = cipkgs;
  };
  nixConfigFile = builtins.toFile "nix.conf" ''
    cores = 0
    max-jobs = 8
  '';
  packagesBase = with tools; {
    inherit nix cachix coreutils gzip tar xz bzip2 shell;
    ci-dirty = (ci-dirty.override { inherit runtimeShell; });
    ci-query = (ci-query.override { inherit nix runtimeShell; });
  } // (config.basePackages or { });
  packages = packagesBase // (config.packages or { }); # TODO: turn this into an overlay?
  packagesShell = {
    inherit less; # some tools invoke less in interactive ttys
  };
  glibcLocales = lib.listToAttrs (map (glibc:
    lib.nameValuePair (builtins.replaceStrings [ "." ] [ "_" ] glibc.version) "${glibc}/lib/locale/locale-archive"
  ) (config.glibcLocales or [ ]));
  envBuilder = lib.makeOverridable ({ pname, packages ? [], command ? "", passAsFile ? [], ... }@args: runCommandNoCC pname ({
    inherit nix prefix cacert runtimeShell;

    passAsFile = [ "source" "env" "rc" "shellBin" ] ++ passAsFile;

    packages = map lib.getBin packages;
    ciRoot = toString ./.;
    nixPathStr = builtins.concatStringsSep ":" (builtins.attrValues (builtins.mapAttrs (k: v: "${k}=${v}") nixPath));
    glibcLocaleVars = lib.optionals hostPlatform.isLinux (lib.mapAttrsToList (name: path:
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
      ${lib.optionalString (config.closeStdin or false) "exec 0<&-"}

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
  '');
}
