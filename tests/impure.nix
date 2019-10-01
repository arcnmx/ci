{ pkgs, config, ... }: {
  ci = {
    url = ".";
    project.name = "tests-impure";
    gh-actions.enable = true;
    env.environment.test = rec {
      jq = config.lib.ci.hostDep "jq" [ "jq" ];
      jqhello = pkgs.writeShellScriptBin "jqhello" ''
        echo '{ "hello": "world" }' | ${jq}/bin/jq -er .hello -
      '';
    };
    project.tasks.impure.inputs = let
      jq = pkgs.mkCiCommand {
        pname = "impure-jq";
        command = ''
          [[ -e /home ]] || (echo "oh no we appear to be in the nix sandbox" >&2; exit 1)
          jqhello
        '';
        displayName = "impure jq host dependency";
        hostExec = true;
      };
      env = pkgs.mkCiCommand {
        pname = "impure-env";
        someVar = "hello";
        command = ''
          [[ $somevar = hello ]]
        '';
        displayName = "impure environment variable";
        hostExec = true;
      };
      pure = pkgs.mkCiCommand {
        pname = "pure-jq";
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
  };
}
