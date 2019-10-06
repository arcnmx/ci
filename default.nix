{ pkgs ? if builtins.getEnv "CI_PLATFORM" == "impure" then true else null
, config ? let env = builtins.getEnv "CI_CONFIG"; in if env != "" then env else null
}@args: import ./nix {
  inherit pkgs;
  configuration = config;
}
