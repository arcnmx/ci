{ pkgs, lib, config, configPath, ... }: with lib; with config.lib.ci; let
  inherit (config.ci.env.bootstrap.packages) ci-query ci-dirty nix;
  cfg = config.ci.exec;
  tasks = mapAttrs (_: { drv, ... }: drv) config.ci.project.tasks;
in {
  options.ci.exec = {
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
    op = mkOption {
      type = types.attrs;
      internal = true;
    };
    colours = mkOption {
      type = types.attrs;
      internal = true;
    };
  };
  options.ci.export = {
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

  config.ci.exec = {
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
      realise = drvs: "${cfg.op.nixRealise} ${toString drvs}"; # --keep-going
      filter = drvImports:
        cfg.op.query drvImports
        + " | ${cfg.op.dirty}";
      filterNoisy = drvImports:
        cfg.op.query drvImports
        + logpipe "${cfg.colours.magenta}::::: Dirty Derivations ::::: ${cfg.colours.green}"
        + " | ${cfg.op.dirty} -v"
        + logpipe "${cfg.colours.magenta}::::::::::::::::::::::::::::: ${cfg.colours.clear}";
      buildDirty = drvImports: cfg.op.realise "$(cat <(${cfg.op.filter drvImports}))";
      build = drvs: cfg.op.realise (map drvOf drvs);
      sourceOps = ''
        function opFilter {
          ${cfg.op.filter "$1"}
        }
        function opFilterNoisy {
          ${cfg.op.filterNoisy "$1"}
        }

        function opRealise {
          if [[ "${cfg.op.realise ""}" = *nix-build* ]]; then
            ${cfg.op.realise ''"$@"''} > /dev/null # we don't want it to spit out paths
          else
            ${cfg.op.realise ''"$@"''}
          fi
        }
      '';
    };
  };

  config.lib.ci = {
    drvOf = drv: builtins.unsafeDiscardStringContext drv.drvPath;
    buildDrvs = drvs: "${nix}/bin/nix-build --no-out-link ${builtins.concatStringsSep " " (map drvOf drvs)}";
    buildDrv = drv: buildDrvs [drv];
    logpipe = msg: " | (cat && echo ${msg} >&2)";
    #logpipe = msg: " | (${config.ci.env.bootstrap.packages.coreutils}/bin/tee >(cat >&2) && echo ${msg} >&2)";
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
      drv = if builtins.isString task then config.ci.project.tasks.${task} else task;
    in cfg.op.build [drv.drv];
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
    in optional (drv.ci.cache.enable or default) drv
      ++ optionals (drv.ci.cache.buildInputs or false) buildInputs # TODO: make this true by default?
      ++ optionals (isFunction drv.ci.cache or null) (drv.ci.cache drv)
      ++ concatMap cacheInputsOf (drv.ci.cache.inputs or []);
    commandExecutor = {
      stdenv ? config.ci.env.bootstrap.pkgs.stdenvNoCC
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

  config.ci.export = {
    environment = config.ci.env.packages.bootstrap;
    source = ''
      CI_ENV=${config.ci.env.packages.test}

      function ci_refresh() {
        local CONFIG_ARGS=(--arg configuration '${toNix configPath}')
        if [[ $# -gt 0 ]]; then
          CONFIG_ARGS=(--argstr configuration "$1")
        fi
        eval "$(${config.ci.env.bootstrap.packages.nix}/bin/nix eval --show-trace --raw source -f ${toString ./.} "''${CONFIG_ARGS[@]}")"
      }

      ${builtins.concatStringsSep "\n" (mapAttrsToList (name: eval: ''
        function ci_${name} {
          ${eval} "$@"
        }
      '') config.ci.export.exec)}
    '';
    shell = pkgs.mkShell {
      nativeBuildInputs = [ config.ci.env.packages.test ] ++
        attrValues config.ci.env.environment.shell;

      shellHook = ''
        eval "${config.ci.export.source}"
        source ${config.ci.env.packages.test}/${config.ci.env.prefix}/env
        ci_env_impure
      '';
    };
    test = buildScriptFor config.ci.project.tasks // {
      # TODO: turn this into a megatask using host-exec so it can all run in parallel? sshd ports though :(
      all = config.ci.env.bootstrap.pkgs.writeShellScriptBin "ci-build" ''
        set -eu
        ${config.ci.export.test}/bin/ci-build
        ${concatStringsSep "\n" (mapAttrsToList (k: v: "echo testing ${k} ... >&2 && ${v.test}/bin/ci-build") config.ci.export.stage)}
      '';
    } // mapAttrs (name: task: buildScriptFor { ${name} = task; }) config.ci.project.tasks;
    exec = {
      shell = ''${buildAndRun [config.ci.env.packages.shell]} -c ci-shell'';
      dirty = buildAnd [ci-query ci-dirty] (cfg.op.filterNoisy taskDrvImports);
      build = buildAnd [ci-query ci-dirty] (cfg.op.buildDirty taskDrvImports);
      buildAll = cfg.op.build taskDrvs;
    } // mapAttrs' (name: value: nameValuePair "task_${name}" (buildTask value)) config.ci.project.tasks
      // config.ci.project.exec;
  };
}
