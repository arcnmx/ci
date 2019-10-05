{ pkgs, ... }: {
  ci = {
    url = ".";
    gh-actions.enable = true;
  };
  name = "tests-tasks";
  environment.test = {
    inherit (pkgs) hello;
  };
  cache.cachix.ci.enable = true;
  jobs = {
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
        allowSubstitutes = false;
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
      impure = pkgs.ci.command {
        name = "impure";
        command = ''
          [[ -z ''${NIX_BUILD_TOP-} ]]
          echo "hello from outside the sandbox"
          [[ -e /root ]]
        '';
        impure = true;
      };
      forgetme = pkgs.ci.command {
        name = "skip-me";
        skip = true;
        command = "false";
      };
      forgetme-reason = pkgs.ci.command {
        name = "skip-me-also";
        skip = "just because";
        command = "false";
      };
      pure = pkgs.ci.command {
        name = "pure";
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
}
