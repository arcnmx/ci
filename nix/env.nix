{ pkgs, lib, config, ... }: with lib; let
  config' = config;
  channels = import ./lib/channels.nix lib;
  channelArgs = {
    inherit (config.lib) channelUrls;
    inherit pkgs;
    bootpkgs = config.nixpkgs.import;
  };
  channelType = channels.channelTypeCoerced (channels.channelType (channelArgs // {
    inherit (config) channels;
    ciOverlayArgs = {
      inherit config;
    };
  }));
  nixpkgsType = channels.channelTypeCoerced (channels.channelType (channelArgs // {
    channels = {
      ci = {
        inherit (config.channels.ci) enable overlays;
      };
      inherit (config.bootstrap) nixpkgs;
    };
    isNixpkgs = true;
    ciOverlayArgs = {
      inherit config;
    };
  }));
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
    nixpkgs = mkOption {
      type = nixpkgsType;
      default = { };
    };
    system = mkOption {
      type = types.nullOr channels.systemType;
      default = null;
    };
    bootstrap = {
      pkgs = mkOption {
        type = types.unspecified;
        default = config.nixpkgs.import;
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
    channels = mkOption {
      type = types.attrsOf channelType;
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
      } // {
        substituters = mkIf (config.cache.substituters != { }) (
          mapAttrsToList (_: s: s.url) config.cache.substituters
        );
        trusted-public-keys = mkIf (any (s: s.publicKeys != []) (attrValues config.cache.substituters)) (
          concatLists (mapAttrsToList (_: s: s.publicKeys) config.cache.substituters)
        );
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
    nixpkgs = {
      args.system = mkIf (config.system != null) (config.lib.ci.mkOptionDefault2 config.system);
      path = config.lib.ci.mkOptionDefault1 (config.lib.nixpkgsPathFor.${builtins.nixVersion} or config.lib.nixpkgsPathFor."19.03");
    };
    channels = {
      nixpkgs.args = with { mkDefault = config.lib.ci.mkOptionDefault1; }; {
        localSystem = mkDefault config.nixpkgs.args.localSystem;
        crossSystem = mkDefault config.nixpkgs.args.crossSystem;
        system = mkDefault config.nixpkgs.args.system;
        config = mapAttrs (_: mkDefault) config.nixpkgs.args.config;
        # TODO: overlays?
        crossOverlays = mkDefault config.nixpkgs.args.crossOverlays;
        stdenvStages = mkDefault config.nixpkgs.args.stdenvStages;
      };
      nixpkgs = {
        path = config.nixpkgs.path;
      };
      ci = {
        version = "modules";
        path = toString ../.;
      };
      # TODO: cipkgs? dunno, this ends up in the environment... but maybe that's fine? you can't get away with building an env without using cipkgs!
    } // mapAttrs (_: mkDefault) (optionalAttrs config.environment.impure (channelsFromEnv screamingSnakeCase "NIX_CHANNELS_"));
    nixPath = {
      nixpkgs = config.lib.ci.storePathFor config.channels.nixpkgs.path;
    } // mapAttrs (_: c: config.lib.ci.storePathFor c.path) config.channels;
    cache.substituters = {
      nixos = {
        url = nixosCache;
        publicKeys = [ nixosKey ];
      };
    } // mapAttrs' (k: v: nameValuePair "${k}.cachix" {
      url = "https://${k}.cachix.org";
      publicKeys = optional (v.publicKey != null) v.publicKey;
    }) (filterAttrs (_: c: c.enable) config.cache.cachix);

    lib = {
      channelUrls = channels.channelUrls {
        inherit (config.lib) nixpkgsChannels;
        inherit (config.lib.ci) githubChannel;
        inherit (systems.elaborate config.nixpkgs.args.system) isDarwin;
      };
      nixpkgsChannels = channels.nixpkgsChannels {
        inherit (config.lib) nixpkgsChannels;
        inherit (systems.elaborate config.nixpkgs.args.system) isLinux;
      };
      nixpkgsPathFor = mapAttrs (_: builtins.fetchTarball) (import ./lib/cipkgs.nix).nixpkgsFor;
      ci = {
        inherit (channels) githubChannel;
        import = config.lib.ci.nixPathImport config.nixPath;
        mkOverrideAdj = mkOverride: adj: content: let
          res = mkOverride content;
        in res // {
          priority = res.priority + adj;
        };
        mkOptionDefault1 = config.lib.ci.mkOverrideAdj mkOptionDefault (-100);
        mkOptionDefault2 = config.lib.ci.mkOverrideAdj config.lib.ci.mkOptionDefault1 (-100);
        storePathFor = path: if hasPrefix builtins.storeDir (toString path)
          then builtins.storePath path
          else if builtins.getEnv "CI_PLATFORM" == "impure" then toString path
          else filteredSource path;
      };
    };

    _module.args = {
      inherit (config.lib.ci) import;
      channels = mapAttrs (_: c: c.import) config.channels // {
        cipkgs = config.nixpkgs.import;
      };
      pkgs = mkOptionDefault config.channels.nixpkgs.import;
    };
  };
}
