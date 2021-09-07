{ pkgs, lib, config, channels, ... }: with lib; {
  name = "example";

  # https://github.com/arcnmx/ci/actions?workflow=example
  ci.gh-actions.enable = true;

  channels = {
    # shorthands are available for common channels
    nixpkgs = "19.09";
    # custom NIX_PATH, pinned channels, etc.
    nur.url = "https://github.com/nix-community/NUR/archive/master.tar.gz";
  };

  # Use a cache to remember which of our tests passed
  cache.cachix.ci.enable = true;

  # We can refer to a special pinned nixpkgs to make packages part of the base environment
  # These are meant to be readily available so that they can be used before caches are set up.
  environment.bootstrap = with channels.cipkgs; {
    inherit hello;
  };

  # dependencies that can use custom caches and channels
  environment.test = let
    nur = channels.nur;
  in {
    inherit (pkgs) lolcat ncurses;
    inherit (nur.repos.dtz.pkgs) crex;
  };

  tasks.hello = {
    # a task is a group of tests to run or packages to build
    name = "hello, world";
    inputs = pkgs.ci.command {
      # commands run tests without necessarily generating any output, they either succeed or fail
      name = "hello";
      displayName = "hihi";
      command = ''
        hello | lolcat
      '';
    };
  };

  jobs = {
    # additional jobs are submodules that can contain overrides to augment our config
    old = {
      channels.nixpkgs = mkForce "18.09";
    };
    mac = {
      system = "x86_64-darwin";
    };
  };

  stages = {
    # stages on the other hand are fresh new sub-configs
    script = {
      gh-actions.jobs.script = {
        # just making sure the provided ./example.sh script works
        name = "example script";
        steps = mkForce [ {
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
    docs = ./docs.nix;
  };

  # May be necessary to include depending on what you're testing or building...
  environment.glibcLocales = [ channels.cipkgs.glibcLocales pkgs.glibcLocales ];

  # we're adding a github-exclusive step here
  ci.gh-actions = {
    emit = true; # normally the existence of other jobs disables the default/implicit job
    export = true; # want our dependencies to be available in $PATH
  };
  gh-actions.jobs = {
    ci.step.crex = {
      # using ci.gh-actions.export, we can also access the environment implicitly
      run = "crex --help | lolcat --force";
    };
  };
}
