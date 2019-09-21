{ config, cipkgs, exec, env }@args: let
  scope = import ./scope.nix { };
  firstOrNull = pred: list: let
    filtered = builtins.filter pred list;
  in if filtered != []
    then builtins.head filtered
    else null;
  configPath' = firstOrNull builtins.pathExists [
    (/. + "${builtins.getEnv "PWD"}/${toString args.config}")
    (/. + toString args.config)
  ];
  configPath = firstOrNull (v: v != null) [
    configPath'
    (toString args.config)
  ];

  nixpkgsChannels = {
    "19.03" = if cipkgs.hostPlatform.isDarwin
      then "nixpkgs-19.03-darwin"
      else "nixos-19.03";
    "19.03-small" = if cipkgs.hostPlatform.isDarwin
      then nixpkgsChannels."19.03"
      else "nixos-19.03-small";
    "19.09" = if cipkgs.hostPlatform.isDarwin
      then "nixpkgs-19.09-darwin"
      else "nixos-19.09";
    "19.09-small" = if cipkgs.hostPlatform.isDarwin
      then nixpkgsChannels."19.09"
      else "nixos-19.09-small";
    unstable = if cipkgs.hostPlatform.isLinux
      then "nixos-unstable"
      else "nixpkgs-unstable";
    unstable-small = if cipkgs.hostPlatform.isLinux
      then "nixos-unstable-small"
      else nixpkgsChannels.unstable;
  };

  nixpkgsSource = { rev, sha256 }: builtins.fetchTarball {
    name = "source";
    url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };
  nixpkgsBundled = {
    # pinned nixpkgs evaluations bundled with nix binary releases (https://hydra.nixos.org/project/nix)
    # TODO: check <nix/config.nix> to make sure these actually line up?
    "2.2.2" = nixpkgsSource {
      rev = "2296f0fc9559d0b6e08a7c07b25bd0a5f03eebe5";
      sha256 = "197f6glm69717a5pj7bwm57vf1wrgh8nb13sa9qpjkz4803xpzdf";
    };
    "2.2.1" = nixpkgsSource {
      rev = "d26f11d38903768bf10036ce70d67e981056424b";
      sha256 = "16d986r76ps7542mbm63dxiavxw9af08l4ffpjp38lpam2cd9zpp";
    };
    "2.3" = nixpkgsSource {
      rev = "56b84277cc8c52318a99802878b0725b2e34648e";
      sha256 = "0rhpkfcfvszvcga7lcy4zqzchglsnvrzphkz59ifp9ihvmxrq14y";
    };
    "19.03" = nixpkgsSource {
      # random pinned stable version from 2019-06ish
      rev = "d7752fc0ebf9d49dc47c70ce4e674df024a82cfa";
      sha256 = "1rw4fgnm403yf67lgnvalndqqy6ln6bz1grd6zylrjblyxnhqkmj";
    };
  };

  # TODO: think about how this will work with flakes. want to expand this to include overlays!
  channelUrls = let
    githubChannel = slug: c: "https://github.com/${slug}/archive/${c}.tar.gz";
  in {
    # TODO: if nixpkgs is a git ref use githubChannel instead
    nixpkgs = c: "https://nixos.org/channels/${nixpkgsChannels.${c} or c}/nixexprs.tar.xz";
    home-manager = githubChannel "rycee/home-manager";
    mozilla = githubChannel "mozilla/nixpkgs-mozilla";
    rust = githubChannel "arcnmx/nixexprs-rust";
    nur = githubChannel "nix-community/NUR";
    arc = githubChannel "arcnmx/nixexprs";
    ci = githubChannel "arcnmx/ci";
  };
  nixPath' = builtins.mapAttrs (name: if channelUrls ? ${name}
    then channelUrls.${name}
    else ch: ch
  ) (out.channels or {});
  nixPath = {
    nixpkgs = config.cipkgs.path;
    cipkgs = config.cipkgs.path;
    ci = toString ./..;
  } // nixPath' // (out.nixPath or {});
  channels = builtins.mapAttrs (k: v: let
    importPath = if cipkgs.lib.hasPrefix "/" v then v else builtins.fetchTarball {
      name = "source";
      url = v;
    };
  in scope.nixPathScopedImport (scope.nixPathList nixPath) importPath config.channelConfig.${k} or {}) nixPath;

  hostPath = with cipkgs.lib; let
    paths' = splitString ":" (builtins.getEnv "PATH");
    paths = builtins.filter (p: p != "") (filter builtins.pathExists paths');
  in map (path: { inherit path; prefix = ""; }) paths;
  hostDep = name: bins: with cipkgs.lib; let
    binTry = map (bin: builtins.tryEval (builtins.findFile hostPath bin)) (toList bins);
    success = all (bin: bin.success) binTry;
    binPaths = map (bin: bin.value) binTry;
    drv = cipkgs.linkFarm "${name}-host-impure" (map (bin: {
      name = "bin/${builtins.baseNameOf bin}";
      path = toString bin;
    }) binPaths);
  in if success then drv else null;
  configArgs = {
    inherit cipkgs nixPath channels nixpkgsBundled hostDep;
    inherit config exec env;
    screamingSnakeCase = with cipkgs.lib; s: builtins.replaceStrings [ "-" ] [ "_" ] (toUpper s);
    cachixFromEnv = { }: let
      cacheName = builtins.getEnv "CACHIX_CACHE";
      signing-key = builtins.getEnv "CACHIX_SIGNING_KEY";
    in if cacheName == "" then {}
      else {
        ${cacheName} = if signing-key != "" then {
          inherit signing-key;
        } else {};
      };
    channelsFromEnv = with cipkgs.lib; trans: prefix: filterAttrs (_: v: v != "") (
      listToAttrs (map (ch: nameValuePair ch (builtins.getEnv "${prefix}${trans ch}")) (attrNames channelUrls))
    );
    ci = configArgs;
    pkgs = cipkgs; # TODO: throw "use cipkgs instead"? This should actually be nixPath.nixpkgs, with configured settings/overlays/etc.

    inherit (cipkgs) mkCiTask mkCiCommand mkCiSystem;
  };

  cache = {
    substituters = with builtins;
      [ "https://cache.nixos.org/" ]
      ++ attrValues (mapAttrs (name: c: c.substituter or "https://${name}.cachix.org") (out.cache.cachix or {}));
    trusted-public-keys = with builtins;
      [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ]
      ++ concatMap (c: c.keys or []) (out.cache.cachix or {});
    cachixUse = with cipkgs.lib;
      attrNames (filterAttrs (_: cachix: !(cachix ? keys)) out.cache.cachix or {});
    cachixKeys = with cipkgs.lib;
      mapAttrs (_: cachix: cachix.signing-key)
      (filterAttrs (_: cachix: !(cachix ? signing-key)) out.cache.cachix or {});
  };

  defaults = {
    #glibcLocales = [ cipkgs.glibcLocales ];
  };
  overrides = {
    inherit nixPath;
    cache = cache // out.cache or {};

    channelConfig = out.channelConfig or {} // {
      nixpkgs = out.channelConfig.nixpkgs or {} // {
        overlays = [ (import ./overlay.nix { inherit env; }) ] ++ out.channelConfig.nixpkgs.overlays or [];
        config = {
          checkMetaRecursively = true;
        } // out.channelConfig.nixpkgs.config or {};
      };
    };

    cipkgs = {
      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/impure.nix
      path = nixpkgsBundled.${builtins.nixVersion} or nixpkgsBundled."19.03";
      pkgs = import config.cipkgs.path (builtins.removeAttrs config.cipkgs [ "path" "pkgs" ]);
    } // out.cipkgs or {} // {
      overlays = [ (import ./overlay.nix { inherit env; }) ] ++ out.cipkgs.overlays or [];
      config = {
        checkMetaRecursively = true;
      } // out.cipkgs.config or {};
    };
    args = configArgs;
  };

  # callPackagesWith without the overrides
  functionArgs = f: f.__functionArgs or (builtins.functionArgs f);
  isFunction = f: builtins.isFunction f || (f ? __functor && isFunction (f.__functor f));
  callWithArgs = autoArgs: fn: args: let
    f = if isFunction fn then fn else import fn;
    auto = builtins.intersectAttrs (functionArgs f) autoArgs;
  in auto // args;
  callWith = autoArgs: fn: args: let
    f = if isFunction fn then fn else import fn;
  in f (callWithArgs autoArgs f args);

  config' = if builtins.isString args.config || builtins.typeOf args.config == "path"
    then scope.nixPathScopedImport (scope.nixPathList nixPath) (toString configPath)
    else args.config;
  config'' = if isFunction config'
    then callWith configArgs config' { }
    else config';
  config''' = config''.ciConfig or config'';
  out = defaults // config''';
  config = out // overrides;
in config
