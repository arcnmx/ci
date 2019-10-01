{ pkgs, lib, config, ... }: with lib; {
  ci.project.name = "example";
  ci.gh-actions.enable = true;
  ci.env = {
    channels = {
      # shorthand for common NIX_PATH channels
      nixpkgs = "19.03";
      # custom NIX_PATH, pinned channels, etc.
      nur.url = "https://github.com/nix-community/NUR/archive/master.tar.gz";
      nur.args = { inherit pkgs; };
    };

    # pinned/stable nixpkgs that become part of the base environment
    environment.bootstrap = with config.ci.env.bootstrap.pkgs; {
      inherit hello;
    };

    # dependencies that can use custom caches and channels
    environment.test = let
      nur = config.ci.env.channels.nur.import;
    in {
      inherit (pkgs) lolcat ncurses;
      inherit (nur.repos.dtz.pkgs) crex;
    };

    glibcLocales = [ config.ci.env.bootstrap.pkgs.glibcLocales pkgs.glibcLocales ];

    cache.cachix.ci.enable = true;
  };
  gh-actions.jobs = {
    ci.steps = mkAfter [ {
      run = "crex --help | lolcat";
    } ];
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
