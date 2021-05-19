lib: with lib; rec {
  channelType = { channelUrls, channels, /*system,*/ bootpkgs, ciOverlayArgs, defaultConfig, isNixpkgs ? false, pkgs ? channels.nixpkgs.import, specialImport }: types.submodule ({ name, config, ... }: {
    options = {
      enable = mkEnableOption "channel" // { default = true; };
      name = mkOption {
        type = types.str;
        default = name;
      };
      version = mkOption {
        type = types.nullOr types.str;
      };
      url = mkOption {
        type = types.nullOr types.str;
      };
      sha256 = mkOption {
        type = types.nullOr types.str;
      };
      path = mkOption {
        type = types.either types.str types.path;
      };
      file = mkOption {
        type = types.nullOr types.str;
      };
      args = mkOption {
        type = if isNixpkgs || name == "nixpkgs"
          then nixpkgsType { inherit channels; }
          else types.attrsOf types.unspecified;
      };
      overlays = mkOption {
        type = types.listOf types.unspecified;
      };
      import = mkOption {
        type = types.unspecified;
        internal = true;
      };
      nixPathImport = mkOption {
        type = types.bool;
        default = false;
      };
    };
    config = {
      version = defaultConfig.${config.name}.version or (mkOptionDefault null);
      sha256 = defaultConfig.${config.name}.sha256 or (mkOptionDefault null);

      args = defaultConfig.${config.name}.args or ({
        nur = {
          nurpkgs = mkOptionDefault bootpkgs;
        };
        ci = { pkgs = mkOptionDefault bootpkgs; };
      }.${config.name} or (mkOptionDefault { }));

      file = defaultConfig.${config.name}.file or (mkOptionDefault {
        mozilla = "package-set.nix";
      }.${config.name} or null);

      overlays = defaultConfig.${config.name}.overlays or (mkOptionDefault {
        rust = [ (config.path + "/overlay.nix") ];
        arc = [ (config.path + "/overlay.nix") ];
        home-manager = [ (config.path + "/overlay.nix") ];
        mozilla = import (config.path + "/overlays.nix");
        nur = [ (self: super: let
          args = optionalAttrs (config.args ? repoOverrides) {
            inherit (config.args) repoOverrides;
          };
        in {
          nur = import config.path (args // {
            nurpkgs = bootpkgs; # can self work here?
            pkgs = self;
          });
          nur-no-pkgs = import config.path (args // {
            nurpkgs = bootpkgs;
          });
        }) ];
        ci = [
          (config.path + "/nix/overlay.nix")
          (import (config.path + "/nix/lib/overlay.nix") ciOverlayArgs)
        ];
      }.${config.name} or []);

      path = mkMerge ([
        (mkIf (config.url != null) (mkDefault (
          if hasPrefix builtins.storeDir (toString config.url) then /. + builtins.storePath config.url
          else if hasPrefix "/" (toString config.url) then toString config.url
          else builtins.fetchTarball ({
            name = "source"; # or config.name?
            inherit (config) url;
          } // optionalAttrs (config.sha256 != null) {
            inherit (config) sha256;
          })
        )))
      ] ++ optional (defaultConfig ? ${config.name}.path) defaultConfig.${config.name}.path);

      url = defaultConfig.${config.name}.url or (mkOptionDefault (
        if config.version != null
          then channelUrls.${config.name} config.version
          else null
      ));

      import = mkOptionDefault (defaultConfig.${config.name}.import or (let
        args = optionalAttrs (isFunction channel && ((functionArgs channel) ? pkgs)) { inherit pkgs; }
          // config.args.ciChannelArgs or config.args;
        file = if config.file != null
          then config.path + "/${config.file}"
          else config.path;
        channel = (if config.nixPathImport then specialImport else import) file;
        imported = if isFunction channel then channel args else channel;
      in imported));
    };
  });
  channelTypeCoerced = channelType: types.coercedTo types.str (version: {
    inherit version;
  }) channelType;
  systemType = types.coercedTo types.str (system: { inherit system; }) (types.attrsOf types.unspecified);
  nixpkgsType = { channels }: types.submodule ({ config, ... }: {
    options = {
      system = mkOption {
        type = systemType;
      };
      localSystem = mkOption {
        type = systemType;
      };
      crossSystem = mkOption {
        type = types.nullOr systemType;
      };
      config = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
      };
      overlays = mkOption {
        type = types.listOf types.unspecified;
        default = [ ];
      };
      crossOverlays = mkOption {
        type = types.listOf types.unspecified;
        default = [ ];
      };
      stdenvStages = mkOption {
        type = types.nullOr types.unspecified;
        default = null;
      };
      ciChannelArgs = mkOption {
        type = types.unspecified;
        internal = true;
      };
    };

    config = {
      localSystem = {
        system = mkOptionDefault builtins.currentSystem;
      };
      crossSystem = mkOptionDefault null;
      system = mkOptionDefault (
        if config.crossSystem != null then config.crossSystem
        else config.localSystem
      );
      config = {
        checkMetaRecursively = mkOptionDefault true;
      };
      overlays = let
        overlayChannels = filterAttrs (k: c: k != "nixpkgs" && c.enable) channels;
        overlays = concatMap (c: c.overlays) (attrValues overlayChannels);
      in map (o: if isFunction o then o else import o) overlays;
      ciChannelArgs = removeAttrs config [
        "_module" "ciChannelArgs" "system" "stdenvStages"
      ] // optionalAttrs (config.stdenvStages != null) {
        inherit (config) stdenvStages;
      } // optionalAttrs (config.crossSystem == null && config.system != config.localSystem) {
        crossSystem = config.system;
      };
    };
  });
  nixpkgsChannels = { nixpkgsChannels, isLinux }: {
    stable = "20.09";
    stable-small = "${config.lib.nixpkgsChannels.stable}-small";
    unstable = if isLinux
      then "nixos-unstable"
      else "nixpkgs-unstable";
    unstable-small = if isLinux
      then "nixos-unstable-small"
      else nixpkgsChannels.unstable;
    "21.05" = nixpkgsChannels.unstable;
    "21.05-small" = nixpkgsChannels.unstable-small;
  };
  # TODO: think about how this will work with flakes. want to expand this to include overlays!
  githubChannel = slug: c: "https://github.com/${slug}/archive/${c}.tar.gz";
  gitlabChannel = slug: c: "https://gitlab.com/${slug}/-/archive/${c}/${baseNameOf slug}-${c}.tar.gz";
  channelUrls = { nixpkgsChannels, githubChannel, gitlabChannel, isDarwin }: {
    # TODO: if nixpkgs is a git ref use githubChannel instead
    nixpkgs = c: let
      c' = nixpkgsChannels.${c} or c;
      stable = builtins.match "([0-9][0-9]\\.[0-9][0-9]).*" c';
      channel = if stable != null then
        (if isDarwin
          then "nixpkgs-${builtins.elemAt stable 0}-darwin"
          else "nixos-${c'}")
        else if builtins.match ".*-.*" c' != null then c'
        else null;
    in if channel != null
      then "https://nixos.org/channels/${channel}/nixexprs.tar.xz"
      else githubChannel "nixos/nixpkgs" c';
    home-manager = githubChannel "rycee/home-manager";
    mozilla = githubChannel "mozilla/nixpkgs-mozilla";
    rust = githubChannel "arcnmx/nixexprs-rust";
    nur = githubChannel "nix-community/NUR";
    arc = githubChannel "arcnmx/nixexprs";
    ci = githubChannel "arcnmx/ci";
    #nmd = gitlabChannel "rycee/nmd"; # gitlab seems to have rate limits (429 Too Many Requests)?
    nmd = githubChannel "arcnmx/nmd";
  };
}
