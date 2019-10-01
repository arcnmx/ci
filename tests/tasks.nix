{ pkgs, ... }: {
  ci = {
    url = ".";
    project.name = "tests-tasks";
    gh-actions.enable = true;
    env.environment.test = {
      inherit (pkgs) hello;
    };
    env.cache.cachix.ci.enable = true;
    project.stages = {
      linux = {
        ci.pkgs.system = "x86_64-linux";
      };
      mac = {
        ci.pkgs.system = "x86_64-darwin";
      };
    };
    project.tasks = {
      build.inputs = let
        magic = "compassion";
        drv = pkgs.runCommand "build-task" {
          inherit magic;

          passthru.ci = {
            tests = [ checkMagic ];
          };
        } ''
          echo $magic > $out;
        '';
        nond = pkgs.runCommand "non-deterministic" {
          passthru.ci.cache.enable = false;
        } ''
          echo ${toString builtins.currentTime} > $out;
        '';
        checkMagic = drv: pkgs.runCommand "check-task" {
          inherit drv magic;
        } ''
          if [[ $(cat $drv) != $magic ]]; then
            echo check test mismatch for $drv
            exit 1
          fi
          touch $out
        '';
        impure = pkgs.mkCiCommand {
          pname = "impure";
          command = ''
            [[ -z ''${NIX_BUILD_TOP-} ]]
            echo "hello from outside the sandbox"
            [[ -e /root ]]
          '';
          hostExec = true;
        };
        forgetme = pkgs.mkCiCommand {
          pname = "skip-me";
          skip = true;
          command = "false";
        };
        forgetme-reason = pkgs.mkCiCommand {
          pname = "skip-me-also";
          skip = "just because";
          command = "false";
        };
        pure = pkgs.mkCiCommand {
          pname = "pure";
          command = ''
            echo hello from inside the $NIX_BUILD_TOP sandbox
          '';
        };
      in [ drv nond impure pure forgetme forgetme-reason ];
      broken = let
        fails = pkgs.runCommand "always-fails" {
          passthru.ci.warn = true;
        } "false";
        depend-broken = pkgs.runCommand "depend-broken" {
          buildInputs = [ fails ];
        } "touch $out";
      in {
        name = "broken stuff";
        inputs = [ fails depend-broken ];
        warn = true;
      };
    };
  };
}
