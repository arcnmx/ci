{ config, exec, env, cipkgs }: let
  scriptData = tasks'': with cipkgs.lib; let
    executor = if drvsExec == [] then null else exec.execSsh {
      connectionDetails = {
        address = "127.0.0.1";
        user = builtins.getEnv "USER";
        port = if builtins.getEnv "CI_PORT" == ""
          then 50650 # u-umm
          else builtins.getEnv "CI_PORT";
      };
      commands = drvsExec;
    };
    drvOf = drv: let
      ph = "${builtins.placeholder drv.name}-${drv.name}";
      drvPath = builtins.tryEval (exec.drvOf drv);
    in
      if drv.ci.omit or false != false || ! drvPath.success then ph
      else drvPath.value;
    skippedTasks = filter (t: t.ci.skip or false != false) (attrValues tasks'');
    drvsSkipped = skippedTasks
      ++ concatMap (t: t.inputsSkipped) tasks
      ++ concatMap (t: t.inputsAll) skippedTasks;
    tasks' = filterAttrs (_: t: t.ci.skip or false == false) tasks'';
    tasks = map (task: task.override (args: let
      # TODO: check if this is correct, we need the flattening logic!
      inputs = task.inputsAll;
    in {
      inputs = filter (drv: ! (drv ? ci.exec)) inputs
        ++ map executor.ci.executor.for (filter (drv: drv ? ci.exec) inputs);
    })) (attrValues tasks');
    drvs = tasks ++ concatMap (task: task.inputs) tasks;
    drvs'exec = concatMap (task: task.inputs) (attrValues tasks');
    drvsExec = filter (drv: drv ? ci.exec) drvs'exec;
    drvAttrs = fn: drvs: listToAttrs (map (drv: nameValuePair (drvOf drv) (fn drv)) drvs);
    drvCachePaths = drv: let
      inputs = exec.cacheInputsOf drv;
      cachePaths = input: builtins.unsafeDiscardStringContext (concatMapStringsSep " " (out: toString input.${out}) input.outputs);
    in concatMapStringsSep " " cachePaths inputs;
  in {
    # structured input data for buildScript
    drvs = map drvOf drvs;
    drvExecutor = if executor == null then "" else executor.exec;
    drvTasks = map drvOf (skippedTasks ++ tasks);
    drvSkipped = drvAttrs (drv:
      if isString (drv.ci.skip or null) then drv.ci.skip
      else if drv.meta.broken or false then "broken"
      else if drv.meta.available or true == false then "unavailable"
      else drv.ci.skip or true) drvsSkipped;
    drvImports = exec.drvImports drvs;
    drvExec = drvAttrs
      (drv: cipkgs.lib.concatStringsSep " " drv.ci.exec)
      (filter (drv: drv ? ci.exec)
        drvs);
    drvWarn = drvAttrs
      (drv: true)
      (filter (drv: drv.ci.warn or false)
        drvs);
    drvCache = drvAttrs drvCachePaths drvs;
    drvInputs = drvAttrs (drv: concatStringsSep " " (map (input: drvOf input) (drv.inputs ++ drv.inputsSkipped))) (tasks ++ skippedTasks);
    drvName = drvAttrs (drv: drv.meta.name or drv.name) (drvs ++ drvsSkipped);
    sourceOps = ''
      function opFilter {
        ${exec.opFilter "$1"}
      }
      function opFilterNoisy {
        ${exec.opFilterNoisy "$1"}
      }

      function opRealise {
        if [[ "${exec.opRealise ""}" = *nix-build* ]]; then
          ${exec.opRealise ''"$@"''} > /dev/null # we don't want it to spit out paths
        else
          ${exec.opRealise ''"$@"''}
        fi
      }
    '';
  };
  inherit (exec) colours;
  script = ''
    #!${env.runtimeShell}
    set -eu

    # inputs:
    source $1
    shift
    eval "$sourceOps"

    OPT_OUT=
    if [[ $# -gt 0 && $1 = -O ]]; then
      OPT_OUT=1
      shift
    fi

    OPT_DRY=
    if [[ $* = *--dry-run* ]]; then
      OPT_DRY=1
    fi

    drv_dirty() {
      drv_skipped $1 || [[ " ''${CI_DRV_DIRTY[@]} " =~ " $1 " ]]
    }

    drv_valid() {
      if drv_skipped $1; then
        return 1
      else
        ${env.nix}/bin/nix-store -u -q --hash $1 > /dev/null 2>&1
      fi
    }

    drv_warn() {
      [[ -n ''${drvWarn[$1]-} ]]
    }

    drv_skipped() {
      [[ -n ''${drvSkipped[$1]-} ]]
    }

    drv_report() {
      # drv, status = ok|fail|cache, nested=1
      local REPORT_MSG REPORT_ICON REPORT_COLOUR

      if [[ $2 = ok ]] && ! drv_dirty $1; then
        REPORT_MSG=cache
      elif [[ $2 = fail && -n $OPT_DRY ]]; then
        REPORT_MSG=dry
      else
        REPORT_MSG=$2
      fi

      case $REPORT_MSG in
        fail)
          if drv_warn $1; then
            REPORT_COLOUR=${colours.yellow}
            REPORT_MSG="failed (allowed, ignored)"
            #REPORT_ICON="⚠️"
            REPORT_ICON="!"
          else
            REPORT_COLOUR=${colours.red}
            REPORT_MSG=failed
            REPORT_ICON=❌
            if [[ -z ''${3-} ]]; then
              EXIT_CODE=1
            fi
          fi
          ;;
        ok)
          REPORT_COLOUR=${colours.blue}
          REPORT_MSG=ok
          REPORT_ICON="✔️"
          CI_CACHE_LIST+=(''${drvCache[$1]-})
          ;;
        cache)
          REPORT_COLOUR=${colours.blue}
          REPORT_MSG="ok (cached)"
          REPORT_ICON="✔️"
          ;;
        skip|dry)
          REPORT_COLOUR=${colours.magenta}
          REPORT_ICON="•"
          if [[ $REPORT_MSG = dry ]]; then
            REPORT_MSG="skipped (dry run)"
          elif [[ -z ''${drvSkipped[$1]-} || ''${drvSkipped[$1]} = 1 ]]; then
            REPORT_MSG="skipped"
          else
            REPORT_MSG="skipped (''${drvSkipped[$1]})"
          fi
          ;;
      esac
      echo "$REPORT_COLOUR''${3+"  "}$REPORT_ICON ''${drvName[$1]} $REPORT_MSG" >&2
    }

    # TODO: verbose option for opFilter vs opFilterNoisy?
    CI_DRV_DIRTY=($(opFilterNoisy $drvImports))
    CI_CACHE_LIST=()
    EXIT_CODE=0

    if [[ -n $drvExecutor ]]; then
      export EX_PIDFILE=$(mktemp)
      $drvExecutor
      trap 'kill -QUIT $(cat $EX_PIDFILE)' EXIT
    fi

    # TODO: use --add-root with --indirect in a ci cache dir?
    if (( ''${#CI_DRV_DIRTY[@]} > 0 )) && ! opRealise "''${CI_DRV_DIRTY[@]}" --show-trace --keep-going "$@" || [[ -n $OPT_DRY ]]; then
      for drv in "''${drvTasks[@]}"; do
        # TODO: ANSI colours: red, yellow, blue
        if drv_valid $drv || ! drv_dirty $drv; then
          # TODO: maybe use path-info -Sh and record the size to show with the results?
          drv_report $drv ok
          for input in ''${drvInputs[$drv]}; do
            if drv_skipped $input; then
              drv_report $input skip 1
            else
              drv_report $input ok 1
            fi
          done
        elif drv_skipped $drv; then
          drv_report $drv skip
          for input in ''${drvInputs[$drv]}; do
            drv_report $input skip 1
          done
        else
          drv_report $drv fail
          for input in ''${drvInputs[$drv]}; do
            if drv_valid $input || ! drv_dirty $input; then
              drv_report $input ok 1
            elif drv_skipped $input; then
              drv_report $input skip 1
            else
              drv_report $input fail 1
              if [[ -z $OPT_DRY ]]; then
                nix-store -r $input --dry-run 2>&1 | (${cipkgs.gnugrep}/bin/grep -vFe 'these derivations will be built' -e "$input" | ${cipkgs.gnused}/bin/sed -n '/^these paths will be fetched/q;p' >&2 || true)
                # TODO: parse the above list and show more info via nix-store query or something?
              fi
            fi
          done
          # TODO: print out part of failure log?
        fi
      done
    else
      for drv in "''${drvTasks[@]}"; do
        if drv_skipped $drv; then
          drv_report $drv skip
        else
          drv_report $drv ok
          for input in ''${drvInputs[$drv]}; do
            if drv_skipped $input; then
              drv_report $input skip 1
            else
              drv_report $input ok 1
            fi
          done
        fi
      done
    fi

    printf %s ${colours.clear} >&2

    if [[ -n $OPT_OUT ]]; then
      echo ''${CI_CACHE_LIST[*]} # allow some other script to handle this
      # TODO: consider listing tasks that aren't cached (local) but don't get rebuilt because dirty filter includes local?
    elif [[ ''${#CI_CACHE_LIST[@]} -gt 0 && -n ''${CACHIX_SIGNING_KEY-} && -n ''${CACHIX_CACHE-} ]]; then
      echo ''${CI_CACHE_LIST[*]} | ${with cipkgs.lib; toString (mapNullable getBin env.cachix)}/bin/cachix push "$CACHIX_CACHE"
    fi

    exit $EXIT_CODE
  '';
  # TODO: manual derivation rather than using stdenv?
  buildScriptFor = tasks: cipkgs.runCommand config.project.name or "ci" ({
    __structuredAttrs = true;
    script = cipkgs.writeScript "ci-build.sh" script;
    attrsPath = "${placeholder "out"}/${env.prefix}/attrs.sh";
    preferLocalBuild = true;
    allowSubstitutes = false;
    builder = builtins.toFile "ci-build.sh" ''
      #!${env.runtimeShell}
      source .attrs.sh

      ${env.coreutils}/bin/cat > ci-build <<EOF
        #!${env.runtimeShell}
        exec $script $attrsPath "\$@"
      EOF
      ${env.coreutils}/bin/install -Dm0755 -t ''${outputs[out]}/bin ci-build
      ${env.coreutils}/bin/install -D .attrs.sh $attrsPath
    '';
  } // scriptData tasks) "";
in {
  inherit buildScriptFor;
  testAll = buildScriptFor config.tasks
    // builtins.mapAttrs (name: task: buildScriptFor { ${name} = task; }) (config.tasks or {});
}
