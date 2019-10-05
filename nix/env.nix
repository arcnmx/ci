{ pkgs, lib, config, ... }: with lib; let
  config' = config;
  envOrNull = envOr null;
  envOr = fallback: key: let
    value = builtins.getEnv key;
  in if value == "" then fallback else value;
  isEnvSet = key: if config.environment.impure
    then envOrNull key != null
    else false;
  channelsFromEnv = trans: prefix: filterAttrs (_: v: v != "") (
    listToAttrs (map (ch: nameValuePair ch (builtins.getEnv "${prefix}${trans ch}")) (attrNames config.lib.channelUrls))
  );
  screamingSnakeCase = s: builtins.replaceStrings [ "-" ] [ "_" ] (toUpper s);
  nixosCache = "https://cache.nixos.org/";
  nixosKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY";
  filteredSource = path: config.bootstrap.pkgs.nix-gitignore.gitignoreSourcePure [
    "/.git"
  ] path; # TODO: name = "source"?
  bootstrapStorePath = v: builtins.storePath (/. + v + "/../..");
  envBuilder = config.bootstrap.pkgs.callPackage (import ./lib/env-builder.nix) { inherit config; };
  needsCache = any (c: c.url != nixosCache) (attrValues config.cache.substituters);
  needsCachix = any (c: c.enable && (c.publicKey == null || c.signingKey != null)) (attrValues config.cache.cachix);
  #envBuilder = { pname, packages, command ? "", ... }: throw "aaa";
in {
  options = {
    nix = {
      corepkgs = {
        config = mkOption {
          type = types.attrsOf types.unspecified;
          default = import <nix/config.nix>;
        };
      };
      config = mkOption {
        type = types.attrsOf types.unspecified;
      };
      configFile = mkOption {
        type = types.path;
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
      };
    };
    bootstrap = {
      pkgs = mkOption {
        type = types.unspecified;
        default = config.ci.pkgs.pkgs;
        internal = true;
      };
      runtimeShell = mkOption {
        type = types.path;
        default = builtins.storePath (/. + config.nix.corepkgs.config.shell);
      };
      packages = {
        # nix appears to expect these to be available in PATH
        tar = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.tar;
        };
        gzip = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.gzip;
        };
        xz = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.xz;
        };
        bzip2 = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.bzip2;
        };
        shell = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.shell;
        };
        coreutils = mkOption {
          type = types.package;
          default = builtins.storePath (/. + config.nix.corepkgs.config.coreutils + "/..");
        };
        nix = mkOption {
          type = types.package;
          default = builtins.storePath (/. + config.nix.corepkgs.config.nixPrefix);
        };
        cachix = mkOption {
          type = types.package;
          default = getBin config.bootstrap.pkgs.cachix;
        };
        ci-dirty = mkOption {
          type = types.package;
          default = (import ./tools { inherit (config.bootstrap) pkgs; }).ci-dirty.override {
            inherit (config.bootstrap) runtimeShell;
          };
        };
        ci-query = mkOption {
          type = types.package;
          default = (import ./tools { inherit (config.bootstrap) pkgs; }).ci-query.override {
            inherit (config.bootstrap) runtimeShell;
            inherit (config.bootstrap.packages) nix;
          };
        };
        ci-build = mkOption {
          type = types.package;
          default = config.bootstrap.pkgs.runCommandNoCC "ci-build.sh" ({
            script = ./lib/build/build.sh;
            inherit (config.bootstrap.packages) nix;
            inherit (config.bootstrap.pkgs) gnugrep gnused;
            inherit (config.bootstrap) runtimeShell;
            inherit (config.lib.ci.op) sourceOps;
            cachix = optionalString needsCachix config.bootstrap.pkgs.cachix;
          } // config.lib.ci.colours) ''
            substituteAll $script $out
            chmod +x $out
          '';
        };
      };
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
          file = mkOption {
            type = types.nullOr types.str;
            default = {
              mozilla = "package-set.nix";
            }.${config.name} or null;
          };
          args = mkOption {
            type = types.attrsOf types.unspecified;
          };
          overlays = mkOption {
            type = types.listOf types.unspecified;
          };
          import = mkOption {
            type = types.unspecified;
            internal = true;
          };
        };

        config = {
          args = let pkgs = config'.channels.nixpkgs.import; in {
            nur = {
              inherit pkgs;
              nurpkgs = config'.bootstrap.pkgs;
            };
            arc = { inherit pkgs; };
            home-manager = { inherit pkgs; };
            mozilla = { inherit pkgs; };
          }.${config.name} or { };
          overlays = {
            rust = [ (config.path + "/overlay.nix") ];
            arc = [ (config.path + "/overlay.nix") ];
            home-manager = [ (config.path + "/overlay.nix") ];
            mozilla = import (config.path + "/overlays.nix");
            #ci = import (config.path + "/nix/lib/overlay.nix");
          }.${config.name} or [];
          path = mkOptionDefault (
            if hasPrefix builtins.storeDir (toString config.url) then /. + builtins.storePath config.url
            else if hasPrefix "/" (toString config.url) then toString config.url
            else builtins.fetchTarball {
              name = "source"; # or config.name?
              inherit (config) url;
            });
          url = mkOptionDefault (config'.lib.channelUrls.${config.name} config.version);
          import = let
            args = if config.name == "nixpkgs"
              then config.args // {
                overlays = config'.ci.pkgs.overlays ++ config.args.overlays or []
                  ++ concatMap (c: c.overlays) (attrValues (filterAttrs (k: _: k != "nixpkgs") config'.channels));
                system = config'.ci.pkgs.system;
                config = config.args.config or {} // config'.ci.pkgs.config;
              } else config.args;
            file = if config.file != null
              then config.path + "/${config.file}"
              else config.path;
          in import file args;
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
      impure = mkOption {
        type = types.bool;
        default = true;
      };
      allowRoot = mkOption {
        type = types.bool;
        default = isEnvSet "CI_ALLOW_ROOT";
      };
      closeStdin = mkOption {
        type = types.bool;
        default = isEnvSet "CI_CLOSE_STDIN";
      };
      glibcLocales = mkOption {
        type = types.listOf types.package;
        default = [ ];
      };
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
        defaultText = ''config.environment.bootstrap'';
      };
    };
    export.env = {
      setup = mkOption {
        type = types.package;
      };
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
    nix = {
      config = mapAttrs (_: mkOptionDefault) {
        cores = 0;
        max-jobs = 8;
        http2 = false;
        max-silent-time = 60 * 30;
        fsync-metadata = false;
        use-sqlite-wal = true;
      };
      configFile = let
        toNixValue = v:
          if v == true then "true"
          else if v == false then "false"
          else toString v;
      in mkOptionDefault (builtins.toFile "nix.conf" ''
        ${concatStringsSep "\n" (mapAttrsToList (k: v: "${k} = ${toNixValue v}") config.nix.config)}
        ${config.nix.extraConfig}
      '');
    };
    environment = {
      bootstrap = mkBefore {
        inherit (config.bootstrap.packages) nix coreutils gzip tar xz bzip2 shell;
      } // optionalAttrs (needsCache) {
        inherit (config.bootstrap.packages) ci-query ci-dirty;
      } // optionalAttrs (needsCachix) {
        inherit (config.bootstrap.packages) cachix;
      };
      shell = mkBefore {
        inherit (config.bootstrap.pkgs) less;
      };
      test = mkBefore config.environment.bootstrap;
    };
    export.env = {
      setup = envBuilder (import ./lib/setup.nix { inherit lib config; });
      bootstrap = envBuilder (import ./lib/bootstrap.nix { inherit lib config; });
      test = envBuilder {
        pname = "ci-env";
        packages = attrValues config.environment.test;
      };
      shell = config.export.env.test.override (old: {
        pname = "ci-shell";
        packages = old.packages ++ builtins.attrValues config.environment.shell;
      });
    };
    cache.cachix = optionalAttrs (isEnvSet "CACHIX_CACHE") {
      ${cachixCache} = {
        signingKey = envOrNull "CACHIX_SIGNING_KEY";
      };
    };
    lib.nixpkgsChannels = let
      inherit (config.bootstrap.pkgs) hostPlatform;
    in {
      stable = "19.03";
      stable-small = "${config.lib.nixpkgsChannels.stable}-small";
      unstable = if hostPlatform.isLinux
        then "nixos-unstable"
        else "nixpkgs-unstable";
      unstable-small = if hostPlatform.isLinux
        then "nixos-unstable-small"
        else nixpkgsChannels.unstable;
      "20.03" = config.lib.nixpkgsChannels.unstable;
      "20.03-small" = config.lib.nixpkgsChannels.unstable-small;
    };
    lib.channelUrls = {
      # TODO: think about how this will work with flakes. want to expand this to include overlays!
      githubChannel = slug: c: "https://github.com/${slug}/archive/${c}.tar.gz";
      # TODO: if nixpkgs is a git ref use githubChannel instead
      nixpkgs = c: let
        c' = config.lib.nixpkgsChannels.${c} or c;
        stable = builtins.match "([0-9][0-9]\\.[0-9][0-9]).*" c';
        channel = if stable != null then
          (if config.bootstrap.pkgs.hostPlatform.isDarwin
            then "nixpkgs-${builtins.elemAt stable 0}-darwin"
            else "nixos-${c'}")
          else if builtins.match ".*-.*" c' != null then c'
          else null;
      in if channel != null
        then "https://nixos.org/channels/${channel}/nixexprs.tar.xz"
        else config.lib.channelUrls.githubChannel "nixos/nixpkgs" c';
      home-manager = config.lib.channelUrls.githubChannel "rycee/home-manager";
      mozilla = config.lib.channelUrls.githubChannel "mozilla/nixpkgs-mozilla";
      rust = config.lib.channelUrls.githubChannel "arcnmx/nixexprs-rust";
      nur = config.lib.channelUrls.githubChannel "nix-community/NUR";
      arc = config.lib.channelUrls.githubChannel "arcnmx/nixexprs";
      ci = config.lib.channelUrls.githubChannel "arcnmx/ci";
    };
    channels = {
      nixpkgs = mkOptionDefault {
        path = config.ci.pkgs.path;
      };
    } // mapAttrs (_: mkDefault) (optionalAttrs config.environment.impure (channelsFromEnv screamingSnakeCase "NIX_CHANNELS_"));
    nixPath = {
      nixpkgs = if hasPrefix builtins.storeDir (toString pkgs.path)
        then builtins.storePath pkgs.path
        else filteredSource pkgs.path;
    } // mapAttrs (_: c: c.path) config.channels;
    cache.substituters = {
      nixos = {
        url = nixosCache;
        publicKeys = [ nixosKey ];
      };
    } // mapAttrs' (k: v: nameValuePair "${k}.cachix" {
      url = "https://${k}.cachix.org";
      publicKeys = optional (v.publicKey != null) v.publicKey;
    }) (filterAttrs (_: c: c.enable) config.cache.cachix);

    lib.ci.import = config.lib.ci.nixPathImport config.nixPath;
    _module.args = {
      import = mapAttrs (_: c: c.import) config.channels // {
        __functor = config.lib.ci.import;
      };
      pkgs = mkOptionDefault config.channels.nixpkgs.import;
    };
  };
}
