{ pkgs, channels, lib, config, configPath, ... }: with lib; with config.lib.ci; let
  inherit (config.bootstrap.packages) ci-query ci-dirty nix;
  cfg = config.exec;
  tasks = mapAttrs (_: { drv, ... }: drv) config.tasks;
in {
  options.exec = {
    useNix2 = mkOption {
      # 2.3 introduced --print-build-logs, and was unsuitable for CI prior to that
      type = types.bool;
      default = versionAtLeast builtins.nixVersion "2.3"; # TODO: check bootstrap.packages.nix version, which may differ?
    };
    verbosity = mkOption {
      # TODO: make quiet delay logs until after build completes?
      type = types.enum [ "build" "quiet" "silent" ];
      default = "build";
    };
  };
  options.export = {
    environment = mkOption {
      type = types.package;
    };
    source = mkOption {
      type = types.lines;
    };
    shell = mkOption {
      type = types.package;
    };
    test = mkOption {
      type = types.unspecified;
    };
    exec = mkOption {
      type = types.attrsOf types.unspecified;
    };
    run = mkOption {
      type = types.attrsOf types.unspecified;
    };
  };

  config.lib.ci = {
    colours = {
      red = ''$'\e[31m''\''';
      green = ''$'\e[32m''\''';
      yellow = ''$'\e[33m''\''';
      blue = ''$'\e[34m''\''';
      magenta = ''$'\e[35m''\''';
      cyan = ''$'\e[36m''\''';
      clear = ''$'\e[0m''\''';
    };
    op = {
      # TODO: add a --substituters flag for any caches mentioned in config?
      nixRealise = if cfg.useNix2
        then "${nix}/bin/nix build ${optionalString (cfg.verbosity == "build") "-L"}"
        else "${nix}/bin/nix-store ${optionalString (cfg.verbosity != "build") "-Q"} -r";
      query = drvImports: "${ci-query}/bin/ci-query -f ${drvImports}";
      dirty = "${ci-dirty}/bin/ci-dirty";
      realise = drvs: "${config.lib.ci.op.nixRealise} ${toString drvs}"; # --keep-going
      filter = drvImports:
        config.lib.ci.op.query drvImports
        + " | ${config.lib.ci.op.dirty}";
      filterNoisy = drvImports:
        config.lib.ci.op.query drvImports
        + logpipe "${config.lib.ci.colours.magenta}::::: Dirty Derivations ::::: ${config.lib.ci.colours.green}"
        + " | ${config.lib.ci.op.dirty} -v"
        + logpipe "${config.lib.ci.colours.magenta}::::::::::::::::::::::::::::: ${config.lib.ci.colours.clear}";
      buildDirty = drvImports: config.lib.ci.op.realise "$(cat <(${config.lib.ci.op.filter drvImports}))";
      build = drvs: config.lib.ci.op.realise (map drvOf drvs);
      sourceOps = ''
        function opFilter {
          ${config.lib.ci.op.filter "$1"}
        }
        function opFilterNoisy {
          ${config.lib.ci.op.filterNoisy "$1"}
        }

        function opRealise {
          if [[ "${config.lib.ci.op.realise ""}" = *nix-build* ]]; then
            ${config.lib.ci.op.realise ''"$@"''} > /dev/null # we don't want it to spit out paths
          else
            ${config.lib.ci.op.realise ''"$@"''}
          fi
        }
      '';
    };
    nixRunner = binName: channels.cipkgs.stdenvNoCC.mkDerivation {
      preferLocalBuild = true;
      allowSubstitutes = false;
      name = "nix-run-wrapper-${binName}";
      defaultCommand = "bash"; # `nix run` execvp's bash by default
      inherit binName;
      inherit (config.bootstrap) runtimeShell;
      passAsFile = [ "buildCommand" "script" ];
      buildCommand = ''
        mkdir -p $out/bin
        substituteAll $scriptPath $out/bin/$defaultCommand
        chmod +x $out/bin/$defaultCommand
      '';
      script = ''
        #!@runtimeShell@
        set -eu

        if [[ -n ''${CI_NO_RUN-} ]]; then
          # escape hatch
          exec bash "$@"
        fi

        # also bail out if we're not called via `nix run`
        #PPID=($(@ps@/bin/ps -o ppid= $$))
        #if [[ $(readlink /proc/$PPID/exe) = */nix ]]; then
        #  exec bash "$@"
        #fi

        IFS=: PATHS=($PATH)
        join_path() {
          local IFS=:
          echo "$*"
        }

        # remove us from PATH
        OPATH=()
        for p in "''${PATHS[@]}"; do
          if [[ $p != @out@/bin ]]; then
            OPATH+=("$p")
          fi
        done
        export PATH=$(join_path "''${OPATH[@]}")

        exec @binName@ "$@"
      '';
    };
    nixRunWrapper = binName: package: channels.cipkgs.stdenvNoCC.mkDerivation {
      name = "nix-run-${binName}";
      preferLocalBuild = true;
      allowSubstitutes = false;
      wrapper = config.lib.ci.nixRunner binName;
      inherit package;
      buildCommand = ''
        mkdir -p $out/nix-support
        echo $package $wrapper > $out/nix-support/propagated-user-env-packages
      '';
    };
    drvOf = drv: builtins.unsafeDiscardStringContext drv.drvPath;
    buildDrvs = drvs: "${nix}/bin/nix-build --no-out-link ${builtins.concatStringsSep " " (map drvOf drvs)}";
    buildDrv = drv: buildDrvs [drv];
    logpipe = msg: " | (cat && echo ${msg} >&2)";
    #logpipe = msg: " | (${config.bootstrap.packages.coreutils}/bin/tee >(cat >&2) && echo ${msg} >&2)";
    drvImports = drvs: builtins.toFile "drvs.nix" ''[
      ${builtins.concatStringsSep "\n" (map (d: "(import ${drvOf d})") drvs)}
    ]'';
    buildAnd = drvs: run:
      ''${buildDrvs drvs} > /dev/null && ${run}'';
    buildAndRun = drvs:
      buildAnd drvs "${nix}/bin/nix run ${toString drvs}";
    taskDrvs = builtins.attrValues tasks;
    taskDrvImports = drvImports taskDrvs;
    buildTask = task: let
      drv = if builtins.isString task then config.tasks.${task} else task;
    in config.lib.ci.op.build [drv.drv];
    toNix = val: with builtins; # honestly why not just use from/to json?
      if isString val then ''"${val}"''
      else if builtins ? isPath && builtins.isPath val then ''${toString val}''
      else if typeOf val == "path" then ''${toString val}''
      else if isList val then ''[ ${concatStringsSep " " (map toNix val)} ]''
      else if isAttrs val then ''{
        ${concatStringsSep "\n" (map (key: ''"${key}" = ${toNix val.${key}};'') (attrNames val))}
      }''
      else if isBool val && val then "true" else if isBool then "false"
      else if isInt val || isFloat val then toString val
      else if val == null then "null"
      else throw "unknown nix value ${toString val}";
    cacheInputsOf = drv: let
      buildInputs = throw "cache.buildInputs unimplemented";
      default = ! isFunction drv.ci.cache or null;
      # TODO: do this recursively over all inputs?
    in optional (drv.ci.cache.enable or default && drv.allowSubstitutes or true) drv
      ++ optionals (drv.ci.cache.buildInputs or false) buildInputs # TODO: make this true by default?
      ++ optionals (isFunction drv.ci.cache or null) (drv.ci.cache drv)
      ++ concatMap cacheInputsOf (drv.ci.cache.inputs or []);
    commandExecutor = {
      stdenv ? channels.cipkgs.stdenvNoCC
    , drv
    , executor
    }: let
      exDrv = stdenv.mkDerivation (executor.attrs // {
        name = "${executor.name}-${builtins.unsafeDiscardStringContext (builtins.baseNameOf drv.outPath)}";
        outputHashMode = "flat";
        outputHashAlgo = "sha256";
        outputHash = "0mdqa9w1p6cmli6976v4wi0sw9r4p5prkj7lzfd1877wk11c9c73";

        commandDrv = drvOf drv;
        nativeBuildInputs = executor.attrs.nativeBuildInputs or [] ++ [ drv ];
        commandExec = drv.ci.exec; # also ensures the command is built before running the executor

        inherit (drv) meta;
        passthru = drv.passthru or {} // {
          ci = builtins.removeAttrs drv.passthru.ci or {} [ "exec" "cache" ] // {
            cache = {
              enable = false;
              inputs = [ drv ];
            };
          };
        };
        buildCommand = ''
          ${executor.buildCommand}
          touch $out
        '';
      });
    in exDrv;
    inherit (import ./lib/exec-ssh.nix { inherit lib config; }) execSsh;
    inherit (import ./lib/build { inherit lib config; }) buildScriptFor;
  };

  config.export = {
    environment = config.export.env.bootstrap;
    source = ''
      CI_ENV=${config.export.env.test}

      function ci_refresh() {
        local CONFIG_ARGS=(--arg configuration '${toNix configPath}')
        if [[ $# -gt 0 ]]; then
          CONFIG_ARGS=(--argstr configuration "$1")
        fi
        eval "$(${config.bootstrap.packages.nix}/bin/nix eval --show-trace --raw source -f ${toString ./.} "''${CONFIG_ARGS[@]}")"
      }

      ${builtins.concatStringsSep "\n" (mapAttrsToList (name: eval: ''
        function ci_${name} {
          ${eval} "$@"
        }
      '') config.export.exec)}
    '';
    shell = pkgs.mkShell {
      nativeBuildInputs = [ config.export.env.test ] ++
        attrValues config.export.env.shell;

      shellHook = ''
        eval "${config.export.source}"
        source ${config.export.env.test}/${global.prefix}/env
        ci_env_impure
      '';
    };
    inherit (config.export.run) test;
    run = {
      setup = config.lib.ci.nixRunWrapper "ci-setup" config.export.env.setup;
      bootstrap = config.lib.ci.nixRunWrapper "ci-setup" config.export.env.bootstrap;
      run = config.lib.ci.nixRunWrapper "ci-run" config.export.env.bootstrap;
    } // {
      test = config.lib.ci.nixRunWrapper "ci-build" (buildScriptFor config.tasks) // {
        # TODO: turn this into a megatask using host-exec so it can all run in parallel? sshd ports though :(
        all = config.lib.ci.nixRunWrapper "ci-build" (channels.cipkgs.writeShellScriptBin "ci-build" ''
          set -eu
          ${config.export.test}/bin/ci-build
          ${concatStringsSep "\n" (mapAttrsToList (k: v: "echo testing ${k} ... >&2 && ${v.test}/bin/ci-build") config.export.job)}
          ${concatStringsSep "\n" (mapAttrsToList (k: v: "echo testing ${k} ... >&2 && ${v.test}/bin/ci-build") config.export.stage)}
        '');
      } // mapAttrs (name: task: config.lib.ci.nixRunWrapper "ci-build" (buildScriptFor { ${name} = task; })) config.tasks;
    };
    exec = {
      shell = ''${buildAndRun [config.export.env.shell]} -c ci-shell'';
      dirty = buildAnd [ci-query ci-dirty] (config.lib.ci.op.filterNoisy taskDrvImports);
      build = buildAnd [ci-query ci-dirty] (config.lib.ci.op.buildDirty taskDrvImports);
      buildAll = config.lib.ci.op.build taskDrvs;
    } // mapAttrs' (name: value: nameValuePair "task_${name}" (buildTask value)) config.tasks
      // config.project.exec;
  };
}
