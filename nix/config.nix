{ config, cipkgs, cipkgsPath }: let
  scope = import ./scope.nix { };
  firstOrNull = pred: list: let
    filtered = builtins.filter pred list;
  in if filtered != []
    then builtins.head filtered
    else null;
  configPath' = firstOrNull builtins.pathExists [
    (/. + "${builtins.getEnv "PWD"}/${toString config}")
    (/. + toString config)
  ];
  configPath = firstOrNull (v: v != null) [
    configPath'
    (toString config)
  ];

  nixpkgsChannels = {
    "19.03" = if cipkgs.hostPlatform.isDarwin
      then "nixpkgs-19.03-darwin"
      else "nixos-19.03";
    "19.03-small" = if cipkgs.hostPlatform.isDarwin
      then nixpkgsChannels."19.03"
      else "nixos-19.03-small";
    unstable = "nixpkgs-unstable";
    unstable-small = if cipkgs.hostPlatform.isDarwin
      then nixpkgsChannels.unstable
      else "nixos-unstable-small";
  };

  nixpkgsSource = { rev, sha256 }: import <nix/fetchurl.nix> {
    name = "source";
    unpack = true;
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
    "19.03" = nixpkgsSource {
      # random pinned stable version from 2019-06ish
      rev = "d7752fc0ebf9d49dc47c70ce4e674df024a82cfa";
      sha256 = "1rw4fgnm403yf67lgnvalndqqy6ln6bz1grd6zylrjblyxnhqkmj";
    };
  };

  channelUrls = let
    githubChannel = slug: c: "https://github.com/${slug}/archive/${c}.tar.gz";
  in {
    # TODO: if nixpkgs is a git ref use githubChannel instead
    nixpkgs = c: "https://nixos.org/channels/${nixpkgsChannels.${c} or c}/nixexprs.tar.xz";
    home-manager = githubChannel "rycee/home-manager";
    mozilla = githubChannel "mozilla/nixpkgs-mozilla";
    nur = githubChannel "nix-community/NUR";
    arc = githubChannel "arcnmx/nixexprs";
    ci = githubChannel "arcnmx/ci";
  };
  nixPath' = builtins.mapAttrs (name: if channelUrls ? ${name}
    then channelUrls.${name}
    else ch: ch
  ) (out.channels or {});
  nixPath = {
    nixpkgs = cipkgsPath;
    cipkgs = cipkgsPath;
    ci = toString ./..;
  } // nixPath' // (out.nixPath or {});
  channels = builtins.mapAttrs (_: v: import v { }) nixPath;

  args = {
    inherit cipkgs nixPath channels nixpkgsBundled;
    screamingSnakeCase = with cipkgs.lib; s: builtins.replaceStrings [ "-" ] [ "_" ] (toUpper s);
    channelsFromEnv = with cipkgs.lib; trans: prefix: filterAttrs (_: v: v != "") (
      listToAttrs (map (ch: nameValuePair ch (builtins.getEnv "${prefix}${trans ch}")) (attrNames channelUrls))
    );
  };

  defaults = {
    cipkgsPath = nixpkgsBundled.${builtins.nixVersion} or nixpkgsBundled."19.03";
    cipkgsConfig = { };
    cipkgs = import out.cipkgsPath { config = out.cipkgsConfig; };
    #glibcLocales = [ cipkgs.glibcLocales ];
  };
  overrides = {
    inherit nixPath;
  };

  config' = if builtins.isString config
    then scope.nixPathScopedImport (scope.nixPathList nixPath) (toString configPath)
    else config;
  config'' = if builtins.isFunction config'
    then config' args
    else config';
  out = defaults // config'';
in out // overrides
