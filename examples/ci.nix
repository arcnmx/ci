{ cipkgs, ... }@ci: let
  pkgs = import <nixpkgs> { };
in { # example config file
  channels = {
    # shorthand for common NIX_PATH channels
    nixpkgs = "19.03";
  } // ci.channelsFromEnv ci.screamingSnakeCase "NIX_CHANNELS_"; # overrides from the environment

  nixPath = {
    # custom NIX_PATH, pinned channels, etc.
    nur = "https://github.com/nix-community/NUR/archive/master.tar.gz";
  };

  # pinned/stable nixpkgs that become part of the base environment
  basePackages = with cipkgs; {
    inherit hello;
  };

  # dependencies that can use custom caches and channels
  packages = let
    nur = import <nur> { inherit pkgs; };
  in {
    inherit (pkgs) lolcat ncurses;
    inherit (nur.repos.dtz.pkgs) crex;
  };

  glibcLocales = [ cipkgs.glibcLocales pkgs.glibcLocales ];

  cache.cachix = {
    arc = {};
  };

  # allow setup to modify host environment
  # (allows /etc/nix/nix.conf modifications)
  allowRoot = (builtins.getEnv "CI_ALLOW_ROOT") != "";
  closeStdin = (builtins.getEnv "CI_CLOSE_STDIN") != "";
}
