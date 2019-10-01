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
        pwd = builtins.getEnv "PWD";
        path = toString configPath;
      in if pwd != "" && hasPrefix pwd path
        then "." + builtins.unsafeDiscardStringContext (removePrefix pwd path)
        else "./ci.nix";
    };
  };
}
