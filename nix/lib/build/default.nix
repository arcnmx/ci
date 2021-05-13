{ lib, config }: with lib; with config.lib.ci; let
  scriptData = tasks: let
    executor = config.project.executor.drv;
    drvOf = drv: let
      ph = "${builtins.placeholder drv.name}-${drv.name}";
      drvPath = builtins.tryEval (config.lib.ci.drvOf drv);
    in
      if drv.ci.omit or false != false || ! drvPath.success then ph
      else drvPath.value;
    tasks'partition = partition (t: t.skip != false) (attrValues tasks);
    tasks'skipped = tasks'partition.right;
    tasks'build = tasks'partition.wrong;
    drvsSkipped = map (t: t.drv) tasks'skipped
      ++ concatMap (t: t.internal.inputs.skipped) tasks'build
      ++ concatMap (t: t.internal.inputs.all) tasks'skipped;
    drvs = map (t: t.drv) tasks'build ++ concatMap (task: (with task.internal.inputs; wrappedImpure ++ pure)) (attrValues tasks);
    drvAttrs = fn: drvs: listToAttrs (map (drv: nameValuePair (drvOf drv) (fn drv)) drvs);
    drvCachePaths = drv: let
      inputs = cacheInputsOf drv;
      cachePaths = input: builtins.unsafeDiscardStringContext (concatMapStringsSep " " (out: toString input.${out}) input.outputs);
    in concatMapStringsSep " " cachePaths inputs;
    cachixCaches = attrValues config.cache.cachix;
    writableCaches = filter (c: c.signingKey != null) cachixCaches;
  in {
    # TODO: support multiple caches
    ${if writableCaches != [ ] then "CACHIX_CACHE" else null} = (head writableCaches).name;
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
    drvInputs = mapAttrs' (_: t: nameValuePair (drvOf t.drv) (concatStringsSep " " (map drvOf (with t.internal.inputs; wrappedImpure ++ pure ++ skipped)))) tasks;
    drvName = drvAttrs (drv: drv.meta.name or drv.name) (drvs ++ drvsSkipped);
    preBuild = concatMapStringsSep "\n" (t: t.preBuild) tasks'build;
  };
  # TODO: manual derivation rather than using stdenv?
  buildScriptFor = tasks: config.bootstrap.pkgs.buildPackages.runCommandNoCC config.name ({
    __structuredAttrs = true;
    attrsPath = "${placeholder "out"}/${(import ../../global.nix).prefix}/attrs.sh";
    preferLocalBuild = true;
    allowSubstitutes = false;
    builder = config.bootstrap.pkgs.writeScript "ci-build.sh" ''
      #!${config.bootstrap.runtimeShell}
      source .attrs.sh

      ${config.bootstrap.packages.coreutils}/bin/install -D .attrs.sh $attrsPath
      for bin in ${config.bootstrap.packages.ci-build}/bin/ci-build*; do
        ${config.bootstrap.packages.coreutils}/bin/cat > ci-build <<EOF
      #!${config.bootstrap.runtimeShell}
      export CI_BUILD_ATTRS=\''${CI_BUILD_ATTRS-$attrsPath}
      export PATH=''${outputs[out]}/bin:\$PATH
      exec $bin "\$@"
      EOF
        ${config.bootstrap.packages.coreutils}/bin/install -Dm0755 ci-build ''${outputs[out]}/bin/''${bin##*/}
      done
    '';
    meta.description = "build and test tasks${optionalString (tasks != {}) " - ${toString (attrNames tasks)}"}";
  } // scriptData tasks) "";
in {
  inherit buildScriptFor;
  /*testAll = buildScriptFor config.tasks
    // builtins.mapAttrs (name: task: buildScriptFor { ${name} = task; }) (config.tasks or {});*/
}
