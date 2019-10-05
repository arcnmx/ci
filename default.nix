{ pkgs ? null
, config ? let
  env = builtins.getEnv "CI_CONFIG";
  impureConfig = if env != "" then env else (import ./nix/global.nix).defaultConfigPath;
  impureConfigRoot = builtins.getEnv "CI_CONFIG_ROOT";
  impureConfigPath = if impureConfigRoot != "" && builtins.match "/.*" impureConfig == null
    then "${impureConfigRoot}/${impureConfig}"
    else impureConfig;
in impureConfigPath
}@args: import ./nix {
  inherit pkgs;
  configuration = config;
}
