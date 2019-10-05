{ pkgs, lib, config, channels, ... }: with lib; {
  name = "example";
  ci.gh-actions = {
    enable = true;
    export = true; # we're adding a step and want our dependencies to be available
  };
  channels = {
    # shorthand for common NIX_PATH channels
    nixpkgs = "19.03";
    # custom NIX_PATH, pinned channels, etc.
    nur.url = "https://github.com/nix-community/NUR/archive/master.tar.gz";
    nur.args = { inherit pkgs; };
  };

  # pinned/stable nixpkgs that become part of the base environment
  environment.bootstrap = with config.bootstrap.pkgs; {
    inherit hello;
  };

  # dependencies that can use custom caches and channels
  environment.test = let
    nur = channels.nur;
  in {
    inherit (pkgs) lolcat ncurses;
    inherit (nur.repos.dtz.pkgs) crex;
  };

  environment.glibcLocales = [ config.bootstrap.pkgs.glibcLocales pkgs.glibcLocales ];

  cache.cachix.ci.enable = true;
  gh-actions.jobs = {
    ci.step.crex = {
      run = "crex --help | lolcat";
    };
    script = {
      name = "example script";
      steps = [ {
        uses = {
          owner = "actions";
          repo = "checkout";
          version = "v1";
        };
      } {
        name = "example.sh";
        run = "./example.sh";
        working-directory = "examples";
      } ];
    };
  };
}
