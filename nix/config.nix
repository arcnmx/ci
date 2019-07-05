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
    inherit cipkgs nixPath channels;
    screamingSnakeCase = with cipkgs.lib; s: builtins.replaceStrings [ "-" ] [ "_" ] (toUpper s);
    channelsFromEnv = with cipkgs.lib; trans: prefix: filterAttrs (_: v: v != "") (
      listToAttrs (map (ch: nameValuePair ch (builtins.getEnv "${prefix}${trans ch}")) (attrNames channelUrls))
    );
  };

  defaults = {
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
