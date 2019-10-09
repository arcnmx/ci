{ pkgs, lib, config, modulesPath, libPath, configPath, rootConfigPath, ... }@args: with lib; let
  channels = import ./lib/channels.nix lib;
  channelArgs = {
    inherit (config.lib) channelUrls;
    inherit pkgs;
    bootpkgs = config.nixpkgs.import;
  };
  channelType = channels.channelTypeCoerced (channels.channelType (channelArgs // {
    inherit (config) channels;
    specialImport = config._module.args.import;
    ciOverlayArgs = args;
    defaultConfig = {
      nixpkgs = {
        args = with { mkDefault = config.lib.ci.mkOptionDefault1; }; {
          localSystem = mkDefault config.nixpkgs.args.localSystem;
          crossSystem = mkDefault config.nixpkgs.args.crossSystem;
          system = mkDefault config.nixpkgs.args.system;
          config = mapAttrs (_: mkDefault) config.nixpkgs.args.config;
          # TODO: overlays?
          crossOverlays = mkDefault config.nixpkgs.args.crossOverlays;
          stdenvStages = mkDefault config.nixpkgs.args.stdenvStages;
        };
        path = config.lib.ci.mkOptionDefault1 config.nixpkgs.path;
      };
      ci = {
        version = config.ci.version;
        path = toString ../.;
      };
      nmd = {
        version = config.lib.ci.mkOptionDefault1 "b437898c2b137c39d9c5f9a1cf62ec630f14d9fc";
        sha256 = config.lib.ci.mkOptionDefault1 "18j1nh53cfpjpdiwn99x9kqpvr0s7hwngyc0a93xf4sg88ww93lq";
        args = {
          pkgs = mkOptionDefault config.bootstrap.pkgs;
          inherit lib;
        };
      };
    } // mapAttrs (_: v: { version = mkDefault v; }) (optionalAttrs config.environment.impure (channelsFromEnv screamingSnakeCase "NIX_CHANNELS_"));
  }));
  nixpkgsType = channels.channelTypeCoerced (channels.channelType (channelArgs // {
    channels = {
      ci = {
        inherit (config.channels.ci) enable overlays;
      };
      inherit (config.bootstrap) nixpkgs;
    };
    specialImport = throw "nixPathImport unsupported";
    isNixpkgs = true;
    ciOverlayArgs = args;
    defaultConfig.nixpkgs = {
      args.system = mkIf (config.system != null) (config.lib.ci.mkOptionDefault2 config.system);
      path = config.lib.ci.mkOptionDefault1 (config.lib.nixpkgsPathFor.${builtins.nixVersion} or config.lib.nixpkgsPathFor."19.09");
      # TODO: defaults in url + sha256 instead? doesn't really matter...
    };
  }));
  inherit (import ./lib/env.nix { inherit lib config; }) env envIsSet;
  channelsFromEnv = trans: prefix: filterAttrs (_: v: v != null) (
    listToAttrs (map (ch: nameValuePair ch (env.get "${prefix}${trans ch}")) (attrNames config.lib.channelUrls))
  );
  screamingSnakeCase = s: builtins.replaceStrings [ "-" ] [ "_" ] (toUpper s);
  nixosCache = "https://cache.nixos.org/";
  nixosKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY";
  filteredSource = path: config.bootstrap.pkgs.nix-gitignore.gitignoreSourcePure [
    "/.git"
  ] path; # TODO: name = "source"?
  bootstrapStorePath = v: builtins.storePath (/. + v + "/../..");
  envBuilder = config.bootstrap.pkgs.buildPackages.callPackage (import ./lib/env-builder.nix) { inherit config; };
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
          defaultText = "import <nix/config.nix>";
          internal = true;
        };
      };
      config = mkOption {
        type = types.attrsOf types.unspecified;
      };
      configFile = mkOption {
        type = types.path;
        internal = true;
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
        defaultText = "corepkgs.shell";
        internal = true;
      };
      packages = {
        # nix appears to expect these to be available in PATH
        tar = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.tar;
          defaultText = "corepkgs.tar";
          visible = false;
        };
        gzip = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.gzip;
          defaultText = "corepkgs.gzip";
          visible = false;
        };
        xz = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.xz;
          defaultText = "corepkgs.xz";
          visible = false;
        };
        bzip2 = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.bzip2;
          defaultText = "corepkgs.bzip2";
          visible = false;
        };
        shell = mkOption {
          type = types.package;
          default = bootstrapStorePath config.nix.corepkgs.config.shell;
          defaultText = "corepkgs.shell";
          visible = false;
        };
        coreutils = mkOption {
          type = types.package;
          default = builtins.storePath (/. + config.nix.corepkgs.config.coreutils + "/..");
          defaultText = "corepkgs.coreutils";
          visible = false;
        };
        nix = mkOption {
          type = types.package;
          default = builtins.storePath (/. + config.nix.corepkgs.config.nixPrefix);
          defaultText = "corepkgs.nix";
        };
        cachix = mkOption {
          type = types.package;
          default = getBin config.bootstrap.pkgs.cachix;
          defaultText = "channels.cipkgs.cachix";
        };
        ci-dirty = mkOption {
          type = types.package;
          default = (import ./tools { inherit (config.bootstrap) pkgs; }).ci-dirty.override {
            inherit (config.bootstrap) runtimeShell;
          };
          defaultText = "channels.cipkgs.ci-dirty";
          visible = false;
        };
        ci-query = mkOption {
          type = types.package;
          default = (import ./tools { inherit (config.bootstrap) pkgs; }).ci-query.override {
            inherit (config.bootstrap) runtimeShell;
            inherit (config.bootstrap.packages) nix;
          };
          defaultText = "channels.cipkgs.ci-query";
          visible = false;
        };
        ci-build = mkOption {
          type = types.package;
          default = config.bootstrap.pkgs.runCommandNoCC "ci-build.sh" ({
            scriptBuild = ./lib/build/build.sh;
            scriptDirty = ./lib/build/dirty.sh;
            scriptRealise = ./lib/build/realise.sh;
            scriptSummarise = ./lib/build/summarise.sh;
            scriptCache = ./lib/build/cache.sh;
            inherit (config.bootstrap.packages) nix;
            inherit (config.bootstrap.pkgs) gnugrep gnused;
            inherit (config.bootstrap) runtimeShell;
            inherit (config.lib.ci.op) sourceOps;
            cachix = optionalString needsCachix config.bootstrap.pkgs.cachix;
          } // config.lib.ci.colours) ''
            mkdir -p $out/bin
            substituteAll $scriptBuild $out/bin/ci-build
            substituteAll $scriptDirty $out/bin/ci-build-dirty
            substituteAll $scriptRealise $out/bin/ci-build-realise
            substituteAll $scriptSummarise $out/bin/ci-build-summarise
            substituteAll $scriptCache $out/bin/ci-build-cache
            chmod +x $out/bin/*
          '';
          defaultText = "channels.cipkgs.ci-build";
          visible = false;
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
        default = envIsSet "CI_ALLOW_ROOT";
        defaultText = ''getEnv "CI_ALLOW_ROOT" != ""'';
      };
      closeStdin = mkOption {
        type = types.bool;
        default = envIsSet "CI_CLOSE_STDIN";
        defaultText = ''getEnv "CI_CLOSE_STDIN" != ""'';
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
        readOnly = true;
      };
      bootstrap = mkOption {
        type = types.package;
        readOnly = true;
      };
      test = mkOption {
        type = types.package;
        readOnly = true;
      };
      shell = mkOption {
        type = types.package;
        readOnly = true;
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
            default = env.get "CACHIX_SIGNING_KEY";
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
    cache.cachix = optionalAttrs (envIsSet "CACHIX_CACHE") {
      ${cachixCache} = {
        signingKey = env.get "CACHIX_SIGNING_KEY";
      };
    };
    channels = {
      nixpkgs = mkOptionDefault { };
      ci = mkOptionDefault { };
      nmd = mkOptionDefault { };
    };
    # TODO: cipkgs? dunno, this ends up in the environment... but maybe that's fine? you can't get away with building an env without using cipkgs!
    nixPath = mapAttrs (_: c: config.lib.ci.storePathFor c.path) config.channels;
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
        inherit (config.lib.ci) githubChannel gitlabChannel;
        inherit (systems.elaborate config.nixpkgs.args.system) isDarwin;
      };
      nixpkgsChannels = channels.nixpkgsChannels {
        inherit (config.lib) nixpkgsChannels;
        inherit (systems.elaborate config.nixpkgs.args.system) isLinux;
      };
      nixpkgsPathFor = mapAttrs (_: builtins.fetchTarball) (import ./lib/cipkgs.nix).nixpkgsFor;
      ci = {
        inherit env;
        inherit (channels) githubChannel gitlabChannel;
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
      inherit (config.lib.ci) import env;
      channels = mapAttrs (_: c: c.import) config.channels // {
        cipkgs = config.nixpkgs.import;
      };
      pkgs = mkOptionDefault config.channels.nixpkgs.import;
    };
  };
}
