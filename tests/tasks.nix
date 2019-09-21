{ ci ? throw "ci" }: let
  pkgs = ci.cipkgs;
in {
  packages = {
    inherit (pkgs) hello;
  };

  tasks = {
    build = let
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
        passthru.ci = {
          cache = false;
        };
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
      impure = ci.mkCiCommand {
        pname = "impure";
        command = ''
          [[ -z ''${NIX_BUILD_TOP-} ]]
          echo "hello from outside the sandbox"
          [[ -e /root ]]
        '';
        hostExec = true;
      };
      forgetme = ci.mkCiCommand {
        pname = "skip-me";
        skip = true;
        command = "false";
      };
      forgetme-reason = ci.mkCiCommand {
        pname = "skip-me-also";
        skip = "just because";
        command = "false";
      };
      pure = ci.mkCiCommand {
        pname = "pure";
        command = ''
          echo hello from inside the $NIX_BUILD_TOP sandbox
          declare -p |grep NIX
        '';
      };
    in ci.mkCiTask {
      pname = "build";
      inputs = [ drv nond impure pure forgetme forgetme-reason ];
    };
    broken = let
      fails = pkgs.runCommand "always-fails" {
        passthru.ci.warn = true;
      } "false";
      depend-broken = pkgs.runCommand "depend-broken" {
        buildInputs = [ fails ];
      } "touch $out";
    in ci.mkCiTask {
      pname = "broken";
      inputs = [ fails depend-broken ];
      warn = true;
    };
  };
}
