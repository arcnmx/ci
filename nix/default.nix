{ config ? {} } @ args: let
  cipkgs = config.cipkgs.pkgs;
  config = import ./config.nix {
    inherit cipkgs;
    config = args.config or {};
    inherit exec env;
  };
  exec = import ./exec.nix {
    inherit config env tasks;
  };
  env = import ./env.nix {
    inherit (config) nixPath;
    inherit cipkgs config;
  } // {
    runtimeEnv = import ./runtime.nix { inherit env; };
    bootstrapEnv = import ./bootstrap.nix {
      inherit env;
      inherit (env) runtimeEnv;
    };
    shellEnv = env.runtimeEnv.override (old: {
      packages = old.packages ++ builtins.attrValues (config.shellPackages or {});
    });
  };
  tasks = config.tasks; # TODO: filter by system or otherwise split these up?
  ci = {
    azure = import ./azure args;
  };
  build = import ./build.nix {
    inherit cipkgs config exec env;
  };
  # TODO:
  # - fix exec/shell TERM
  res = {
    inherit ci tasks;

    test = build.testAll; # weird rename here hmm

    env = env.bootstrapEnv // env;
    exec = exec.exec
      // cipkgs.lib.mapAttrs' (name: value: cipkgs.lib.nameValuePair "task_${name}" (exec.buildTask value)) config.tasks
      // config.exec or {};

    source = ''
      CI_ENV=${env.runtimeEnv}

      function ci_refresh() {
        local CONFIG_ARGS=(--arg config '${exec.toNix args.config}')
        if [[ $# -gt 0 ]]; then
          CONFIG_ARGS=(--argstr config "$1")
        fi
        eval "$(${env.nix}/bin/nix eval --show-trace --raw source -f ${toString ./default.nix} "''${CONFIG_ARGS[@]}")"
      }

      ${builtins.concatStringsSep "\n" (cipkgs.lib.mapAttrsToList (name: eval: ''
        function ci_${name} {
          ${eval} "$@"
        }
      '') res.exec)}
    '';

    shell = config.args.pkgs.mkShell {
      nativeBuildInputs = env.runtimeEnv;

      shellHook = ''
        eval "${res.source}"
        source ${env.runtimeEnv}/${env.prefix}/env
        ci_env_impure
      '';
    };

  };
in res
