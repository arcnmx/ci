{ config, configPath, lib, ... }: with lib; let
  cfg = config.ci;
in {
  options.ci = {
    version = mkOption {
      type = types.str;
      default = "modules"; # TODO: adjust once released
    };
    url = mkOption {
      type = types.str;
      default = "https://github.com/arcnmx/ci/archive/${cfg.version}.tar.gz";
    };
    configPath = mkOption {
      type = types.str;
      # TODO: check for config.ci.env.impure first?
      default = let
        root = builtins.getEnv "CI_CONFIG_ROOT";
        pwd = builtins.getEnv "PWD";
        configRoot = if root != "" then root else pwd;
        path = toString configPath;
      in if configRoot != "" && hasPrefix configRoot path
        then "." + removePrefix configRoot path
        else (import ./global.nix).defaultConfigPath;
    };
  };

  options.export.doc = {
    json = mkOption {
      type = types.unspecified;
    };
    manPages = mkOption {
      type = types.package;
    };
    manual = mkOption {
      type = types.package;
    };
    open = mkOption {
      type = types.package;
    };
  };

  config.export.doc = {
    inherit (config.bootstrap.pkgs.ci.doc) manPages manual open json;
  };
}
