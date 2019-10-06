{ pkgs, config, ... }: {
  ci = {
    url = ".";
    gh-actions.enable = true;
  };
  name = "tests-impure";
  environment.test = rec {
    jq = config.lib.ci.hostDep "jq" [ "jq" ];
    jqhello = pkgs.writeShellScriptBin "jqhello" ''
      echo '{ "hello": "world" }' | ${jq}/bin/jq -er .hello -
    '';
  };
  tasks.impure.inputs = let
    jq = pkgs.ci.command {
      name = "impure-jq";
      command = ''
        [[ -e /home ]] || (echo "oh no we appear to be in the nix sandbox" >&2; exit 1)
        jqhello
      '';
      displayName = "impure jq host dependency";
      impure = true;
    };
    env = pkgs.ci.command {
      name = "impure-env";
      someVar = "hello";
      command = ''
        [[ $someVar = hello ]]
      '';
      displayName = "impure environment variable";
      impure = true;
    };
    pure = pkgs.ci.command {
      name = "pure-jq";
      command = ''
        type jqhello
        if [[ ! -e /home ]]; then
          # skip this test if nix builder isn't sandboxed
          ! jqhello
        fi
      '';
      displayName = "jq host dependency should fail inside sandbox";
    };
  in [ jq env pure ];
}
