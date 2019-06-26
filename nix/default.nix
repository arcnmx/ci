{ config ? {} } @ args: let
  cipkgsPath = let
    rev = "d7752fc0ebf9d49dc47c70ce4e674df024a82cfa";
    sha256 = "1rw4fgnm403yf67lgnvalndqqy6ln6bz1grd6zylrjblyxnhqkmj";
  in builtins.fetchTarball {
    name = "nixpkgs-19.03-2019-06";
    url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };
  cipkgs = import cipkgsPath { };
  config = import ./config.nix {
    inherit cipkgs cipkgsPath;
    config = args.config or {};
  };
in {
  env = import ./env.nix {
    inherit (config) nixPath;
    inherit cipkgs config;
  };

  ci = {
    azure = import ./azure args;
  };

  exec = {
  };
}
