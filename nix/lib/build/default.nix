{ lib, config }: with lib; with config.lib.ci; let
  scriptData = tasks: let
    executor = config.ci.project.executor.drv;
    drvOf = drv: let
      ph = "${builtins.placeholder drv.name}-${drv.name}";
      drvPath = builtins.tryEval (config.lib.ci.drvOf drv);
    in
      if drv.ci.omit or false != false || ! drvPath.success then ph
      else drvPath.value;
    tasks'partition = partition (t: t.skip) (attrValues tasks);
    tasks'skipped = tasks'partition.right;
    tasks'build = tasks'partition.wrong;
    drvsSkipped = map (t: t.drv) tasks'skipped
      ++ concatMap (t: t.internal.inputs.skipped) tasks'build
      ++ concatMap (t: t.internal.inputs.all) tasks'skipped;
    drvs = map (t: t.drv) tasks'build ++ concatMap (task: task.internal.inputs.valid) (attrValues tasks);
    drvAttrs = fn: drvs: listToAttrs (map (drv: nameValuePair (drvOf drv) (fn drv)) drvs);
    drvCachePaths = drv: let
      inputs = cacheInputsOf drv;
      cachePaths = input: builtins.unsafeDiscardStringContext (concatMapStringsSep " " (out: toString input.${out}) input.outputs);
    in concatMapStringsSep " " cachePaths inputs;
  in {
    # TODO: error on multiple caches
    ${if config.ci.env.cache.cachix != { } then "CACHIX_CACHE" else null} = (head (attrValues config.ci.env.cache.cachix)).name;
    # structured input data for buildScript
    drvs = map drvOf drvs;
    drvExecutor = if executor == null then "" else executor.exec;
    drvTasks = mapAttrsToList (_: t: drvOf t.drv) tasks;
    drvSkipped = drvAttrs (drv:
      if isString (drv.ci.skip or null) then drv.ci.skip
      else if drv.meta.broken or false then "broken"
      else if drv.meta.available or true == false then "unavailable"
      else drv.ci.skip or true) drvsSkipped;
    drvImports = drvImports drvs;
    drvWarn = drvAttrs
      (drv: true)
      (filter (drv: drv.ci.warn or false)
        drvs);
    drvCache = drvAttrs drvCachePaths drvs;
    drvInputs = mapAttrs' (_: t: nameValuePair (drvOf t.drv) (concatStringsSep " " (map drvOf t.internal.inputs.all))) tasks;
    drvName = drvAttrs (drv: drv.meta.name or drv.name) (drvs ++ drvsSkipped);
  };
  # TODO: manual derivation rather than using stdenv?
  buildScriptFor = tasks: config.ci.env.bootstrap.pkgs.runCommandNoCC config.ci.project.name ({
    __structuredAttrs = true;
    attrsPath = "${placeholder "out"}/${config.ci.env.prefix}/attrs.sh";
    preferLocalBuild = true;
    allowSubstitutes = false;
    builder = config.ci.env.bootstrap.pkgs.writeScript "ci-build.sh" ''
      #!${config.ci.env.bootstrap.runtimeShell}
      source .attrs.sh

      ${config.ci.env.bootstrap.packages.coreutils}/bin/cat > ci-build <<EOF
        #!${config.ci.env.bootstrap.runtimeShell}
        exec ${config.ci.env.bootstrap.packages.ci-build} $attrsPath "\$@"
      EOF
      ${config.ci.env.bootstrap.packages.coreutils}/bin/install -Dm0755 -t ''${outputs[out]}/bin ci-build
      ${config.ci.env.bootstrap.packages.coreutils}/bin/install -D .attrs.sh $attrsPath
    '';
  } // scriptData tasks) "";
in {
  inherit buildScriptFor;
  /*testAll = buildScriptFor config.tasks
    // builtins.mapAttrs (name: task: buildScriptFor { ${name} = task; }) (config.tasks or {});*/
}
