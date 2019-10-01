{ pkgs, lib, config, ... }: with lib; let
  config' = config;
  envOrNull = envOr null;
  envOr = fallback: key: let
    value = builtins.getEnv key;
  in if value == "" then fallback else value;
  isEnvSet = key: if cfg.impure
    then envOrNull key != null
    else false;
  channelsFromEnv = trans: prefix: filterAttrs (_: v: v != "") (
    listToAttrs (map (ch: nameValuePair ch (builtins.getEnv "${prefix}${trans ch}")) (attrNames cfg.channelUrls))
  );
  screamingSnakeCase = s: builtins.replaceStrings [ "-" ] [ "_" ] (toUpper s);
  nixosCache = "https://cache.nixos.org/";
  nixosKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY";
  filteredSource = path: cfg.bootstrap.pkgs.nix-gitignore.gitignoreSourcePure [
    "/.git"
  ] path; # TODO: name = "source"?
  cfg = config.ci.env;
  bootstrapStorePath = v: builtins.storePath (/. + v + "/../..");
  envBuilder = cfg.bootstrap.pkgs.callPackage (import ./lib/env-builder.nix) { inherit config; };
  needsCache = any (c: c.url != nixosCache) (attrValues cfg.cache.substituters);
  needsCachix = any (c: c.enable && (c.publicKey == null || c.signingKey != null)) (attrValues cfg.cache.cachix);
  #envBuilder = { pname, packages, command ? "", ... }: throw "aaa";
in {
  options.ci.env = {
    prefix = mkOption {
      type = types.str;
      default = "ci";
    };
    bootstrap = {
      pkgs = mkOption {
        type = types.unspecified;
        default = config.ci.pkgs.pkgs;
        internal = true;
      };
      runtimeShell = mkOption {
        type = types.path;
        default = builtins.storePath (/. + cfg.bootstrap.nix.corepkgs.config.shell);
      };
      packages = {
        # nix appears to expect these to be available in PATH
        tar = mkOption {
          type = types.package;
          default = bootstrapStorePath cfg.bootstrap.nix.corepkgs.config.tar;
        };
        gzip = mkOption {
          type = types.package;
          default = bootstrapStorePath cfg.bootstrap.nix.corepkgs.config.gzip;
        };
        xz = mkOption {
          type = types.package;
          default = bootstrapStorePath cfg.bootstrap.nix.corepkgs.config.xz;
        };
        bzip2 = mkOption {
          type = types.package;
          default = bootstrapStorePath cfg.bootstrap.nix.corepkgs.config.bzip2;
        };
        shell = mkOption {
          type = types.package;
          default = bootstrapStorePath cfg.bootstrap.nix.corepkgs.config.shell;
        };
        coreutils = mkOption {
          type = types.package;
          default = builtins.storePath (/. + cfg.bootstrap.nix.corepkgs.config.coreutils + "/..");
        };
        nix = mkOption {
          type = types.package;
          default = builtins.storePath (/. + cfg.bootstrap.nix.corepkgs.config.nixPrefix);
        };
        cachix = mkOption {
          type = types.package;
          default = getBin cfg.bootstrap.pkgs.pkgs.cachix;
        };
        ci-dirty = mkOption {
          type = types.package;
          default = (import ./tools { inherit (cfg.bootstrap) pkgs; }).ci-dirty.override {
            inherit (cfg.bootstrap) runtimeShell;
          };
        };
        ci-query = mkOption {
          type = types.package;
          default = (import ./tools { inherit (cfg.bootstrap) pkgs; }).ci-query.override {
            inherit (cfg.bootstrap) runtimeShell;
            inherit (cfg.bootstrap.packages) nix;
          };
        };
        ci-build = mkOption {
          type = types.package;
          default = cfg.bootstrap.pkgs.runCommandNoCC "ci-build.sh" ({
            script = ./lib/build/build.sh;
            inherit (cfg.bootstrap.packages) nix;
            inherit (cfg.bootstrap.pkgs) gnugrep gnused;
            inherit (cfg.bootstrap) runtimeShell;
            inherit (config.ci.exec.op) sourceOps;
            cachix = optionalString needsCachix cfg.bootstrap.pkgs.cachix;
          } // config.ci.exec.colours) ''
            substituteAll $script $out
            chmod +x $out
          '';
        };
      };
      nix = {
        corepkgs = {
          config = mkOption {
            type = types.attrsOf types.unspecified;
            default = import <nix/config.nix>;
          };
        };
        config = mkOption {
          type = types.attrs;
          default = {
            cores = 0;
            max-jobs = 8;
          };
        };
        configFile = mkOption {
          type = types.path;
          default = builtins.toFile "nix.conf" (concatStringsSep "\n" (mapAttrsToList (k: v: "${k} = ${toString v}") cfg.bootstrap.nix.config));
        };
      };
      allowRoot = mkOption {
        type = types.bool;
        default = isEnvSet "CI_ALLOW_ROOT";
      };
      closeStdin = mkOption {
        type = types.bool;
        default = isEnvSet "CI_CLOSE_STDIN";
      };
    };
    impure = mkOption {
      type = types.bool;
      default = true;
    };
    glibcLocales = mkOption {
      type = types.listOf types.package;
      default = [ ];
    };
    nixpkgsChannels = mkOption {
      type = types.attrs;
    };
    channelUrls = mkOption {
      type = types.attrs;
    };
    channels = let
      channelType = types.submodule ({ name, config, ... }: {
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };
          version = mkOption {
            type = types.str;
          };
          url = mkOption {
            type = types.str;
          };
          path = mkOption {
            type = types.str;
          };
          args = mkOption {
            type = types.attrs;
            default = { };
          };
          import = mkOption {
            type = types.unspecified;
            internal = true;
          };
        };

        config = {
          path = mkOptionDefault (
            if hasPrefix builtins.storeDir (toString config.url) then /. + builtins.storePath config.url
            else if hasPrefix "/" (toString config.url) then toString config.url
            else builtins.fetchTarball {
              name = "source"; # or config.name?
              inherit (config) url;
            });
          url = mkOptionDefault (cfg.channelUrls.${config.name} config.version);
          import = let
            args = if config.name == "nixpkgs"
              then config.args // {
                overlays = config'.ci.pkgs.overlays ++ config.args.overlays or [];
                system = config'.ci.pkgs.system;
                config = config.args.config or {} // config'.ci.pkgs.config;
              } else config.args;
          in import config.path args;
        };
      });
      fudge = types.coercedTo types.str (version: {
        inherit version;
      }) channelType;
    in mkOption {
      type = types.attrsOf fudge;
    };
    nixPath = mkOption {
      type = types.attrsOf types.path;
    };
    environment = {
      bootstrap = mkOption {
        type = types.attrsOf types.package;
        defaultText = ''with pkgs; { inherit nix coreutils gzip tar xz bzip2 shell; }'';
      };
      shell = mkOption {
        type = types.attrsOf types.package;
        defaultText = ''{ inherit (pkgs) less; }'';
      };
      test = mkOption {
        type = types.attrsOf types.package;
        defaultText = ''config.ci.environment.bootstrap'';
      };
    };
    packages = {
      bootstrap = mkOption {
        type = types.package;
      };
      test = mkOption {
        type = types.package;
      };
      shell = mkOption {
        type = types.package;
      };
    };
    cache = let
      substituterType = types.submodule ({ ... }: {
        options = {
          url = mkOption {
            type = types.str;
          };
          publicKeys = mkOption {
            type = types.listOf types.str;
          };
        };
      });
      cachixType = types.submodule ({ name, ... }: {
        options = {
          enable = mkEnableOption "cachix cache" // {
            default = true;
          };
          name = mkOption {
            type = types.str;
            default = name;
          };
          publicKey = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          signingKey = mkOption {
            type = types.nullOr types.str;
            default = envOrNull "CACHIX_SIGNING_KEY";
          };
        };
      });
    in {
      substituters = mkOption {
        type = types.attrsOf substituterType;
        defaultText = nixosCache;
      };
      cachix = mkOption {
        type = types.attrsOf cachixType;
        default = { };
      };
    };
  };
  config = {
    ci.env.environment = {
      bootstrap = mkBefore {
        inherit (cfg.bootstrap.packages) nix coreutils gzip tar xz bzip2 shell;
      } // optionalAttrs (needsCache) {
        inherit (cfg.bootstrap.packages) ci-query ci-dirty;
      } // optionalAttrs (needsCachix) {
        inherit (cfg.bootstrap.packages) cachix;
      };
      shell = mkBefore {
        inherit (cfg.bootstrap.pkgs) less;
      };
      test = mkBefore cfg.environment.bootstrap;
    };
    ci.env.packages.bootstrap = envBuilder (import ./lib/bootstrap.nix { inherit lib config; });
    ci.env.packages.test = envBuilder {
      pname = "ci-env";
      packages = attrValues cfg.environment.test;
    };
    ci.env.packages.shell = cfg.packages.test.override (old: {
      pname = "ci-shell";
      packages = old.packages ++ builtins.attrValues cfg.environment.shell;
    });
    ci.env.cache.cachix = optionalAttrs (isEnvSet "CACHIX_CACHE") {
      ${cachixCache} = {
        signingKey = envOrNull "CACHIX_SIGNING_KEY";
      };
    };
    ci.env.nixpkgsChannels = let
      inherit (cfg.bootstrap.pkgs) hostPlatform;
    in {
      stable = "19.03";
      stable-small = "${cfg.nixpkgsChannels.stable}-small";
      unstable = if hostPlatform.isLinux
        then "nixos-unstable"
        else "nixpkgs-unstable";
      unstable-small = if hostPlatform.isLinux
        then "nixos-unstable-small"
        else nixpkgsChannels.unstable;
      "20.03" = cfg.nixpkgsChannels.unstable;
      "20.03-small" = cfg.nixpkgsChannels.unstable-small;
    };
    ci.env.channelUrls = {
      # TODO: think about how this will work with flakes. want to expand this to include overlays!
      githubChannel = slug: c: "https://github.com/${slug}/archive/${c}.tar.gz";
      # TODO: if nixpkgs is a git ref use githubChannel instead
      nixpkgs = c: let
        c' = cfg.nixpkgsChannels.${c} or c;
        stable = builtins.match "([0-9][0-9]\\.[0-9][0-9]).*" c';
        channel = if stable != null then
          (if cfg.bootstrap.pkgs.hostPlatform.isDarwin
            then "nixpkgs-${builtins.elemAt stable 0}-darwin"
            else "nixos-${c'}")
          else if builtins.match ".*-.*" c' != null then c'
          else null;
      in if channel != null
        then "https://nixos.org/channels/${channel}/nixexprs.tar.xz"
        else cfg.channelUrls.githubChannel "nixos/nixpkgs" c';
      home-manager = cfg.channelUrls.githubChannel "rycee/home-manager";
      mozilla = cfg.channelUrls.githubChannel "mozilla/nixpkgs-mozilla";
      rust = cfg.channelUrls.githubChannel "arcnmx/nixexprs-rust";
      nur = cfg.channelUrls.githubChannel "nix-community/NUR";
      arc = cfg.channelUrls.githubChannel "arcnmx/nixexprs";
      ci = cfg.channelUrls.githubChannel "arcnmx/ci";
    };
    ci.env.channels = {
      nixpkgs = mkOptionDefault {
        path = config.ci.pkgs.path;
      };
    } // mapAttrs (_: mkDefault) (optionalAttrs cfg.impure (channelsFromEnv screamingSnakeCase "NIX_CHANNELS_"));
    ci.env.nixPath = {
      nixpkgs = if hasPrefix builtins.storeDir (toString pkgs.path)
        then builtins.storePath pkgs.path
        else filteredSource pkgs.path;
    } // mapAttrs (_: c: c.path) cfg.channels;
    ci.env.cache.substituters = {
      nixos = {
        url = nixosCache;
        publicKeys = [ nixosKey ];
      };
    } // mapAttrs' (k: v: nameValuePair "${k}.cachix" {
      url = "https://${k}.cachix.org";
      publicKeys = optional (v.publicKey != null) v.publicKey;
    }) (filterAttrs (_: c: c.enable) cfg.cache.cachix);

    lib.ci.import = config.lib.ci.nixPathImport config.ci.env.nixPath;
    _module.args = {
      import = config.lib.ci.import;
      pkgs = mkOptionDefault config.ci.env.channels.nixpkgs.import;
    };
  };
}
