{ config ? {} } @ args: let
  config = import ./config.nix {
    inherit (config) cipkgs cipkgsPath;
    config = args.config or {};
  };
in {
  env = import ./env.nix {
    inherit (config) cipkgs nixPath;
    inherit config;
  };

  ci = {
    azure = import ./azure args;
  };

  exec = {
  };
}
