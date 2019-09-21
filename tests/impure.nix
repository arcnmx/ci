{ pkgs ? import <nixpkgs> { }, ci ? throw "ci" }: {
  ciConfig = {
    basePackages = rec {
      jq = ci.hostDep "jq" [ "jq" ];
      jqhello = pkgs.writeShellScriptBin "jqhello" ''
        echo '{ "hello": "world" }' | ${jq}/bin/jq -er .hello -
      '';
    };
    tasks = {
      impure = let
        jq = ci.mkCiCommand {
          pname = "impure-jq";
          command = ''
            [[ -e /home ]] || (echo "oh no we appear to be in the nix sandbox" >&2; exit 1)
            jqhello
          '';
          displayName = "impure jq host dependency";
          hostExec = true;
        };
        env = ci.mkCiCommand {
          pname = "impure-env";
          someVar = "hello";
          command = ''
            [[ $somevar = hello ]]
          '';
          displayName = "impure environment variable";
          hostExec = true;
        };
        pure = ci.mkCiCommand {
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
      in ci.mkCiTask {
        pname = "impure";
        inputs = [ jq env pure ];
      };
    };
  };
}
