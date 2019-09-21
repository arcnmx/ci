{ ci ? throw "ci" }: let
  #pkgs = import <nixpkgs> { };
  pkgs = ci.cipkgs;
  rustChannel = import <rust> { inherit pkgs; };
  rust = rustChannel.stable;
in {
  channels = {
    #nixpkgs = "19.03";
    rust = "master";
  } // ci.channelsFromEnv ci.screamingSnakeCase "NIX_CHANNELS_";

  packages = {
    inherit (stable) cargo;
  };

  shellPackages = {
    inherit (stable) rustc;
  };

  cache.cachix = {
{% for name, key in cookiecutter.cachix_keys.items() %}
    {{name}} = {
      keys = ["{{key}}"];
    };
{% endfor %}
  };

  allowRoot = (builtins.getEnv "CI_ALLOW_ROOT") != "";
  closeStdin = (builtins.getEnv "CI_CLOSE_STDIN") != "";

  tasks = {
    build = let
      build = rust.callPackage ./derivation.nix {
      };
    in ci.mkCiTask {
      pname = "build";
      inputs = [
        build
      ];
    };
  };
}
