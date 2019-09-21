{ config, env, tasks }: let
  inherit (env) nix;
  inherit (env.packagesBase) coreutils ci-query ci-dirty;

  # TODO: add a --substituters flag for any caches mentioned in config?
  useNix2 = true;
  # TODO: support a quiet flag, ci script can show logs after?
  nixRealise = if useNix2
    then "${nix}/bin/nix build -L"
    else "${nix}/bin/nix-store -r";

  drvOf = drv: builtins.unsafeDiscardStringContext drv.drvPath;
  buildDrvs = drvs: "${nix}/bin/nix-build --no-out-link ${builtins.concatStringsSep " " (map drvOf drvs)}";
  buildDrv = drv: buildDrvs [drv];
  logpipe = msg: " | (${coreutils}/bin/tee >(cat >&2) && echo ${msg} >&2)";
  drvImports = drvs: builtins.toFile "drvs.nix" ''[
    ${builtins.concatStringsSep "\n" (map (d: "(import ${drvOf d})") drvs)}
  ]'';
  opQuery = drvImports: "${ci-query}/bin/ci-query -f ${drvImports}";
  opDirty = "${ci-dirty}/bin/ci-dirty";
  opRealise = drvs: "${nixRealise} ${toString drvs}"; # --keep-going
  opFilter = drvImports:
    opQuery drvImports
    + " | ${opDirty}";
  opFilterNoisy = drvImports:
    opQuery drvImports
    + logpipe "${colours.magenta}::::: Dirty Derivations ::::: ${colours.green}"
    + " | ${opDirty}"
    + logpipe "${colours.magenta}::::::::::::::::::::::::::::: ${colours.clear}";
  opBuildDirty = drvImports: opRealise "$(cat <(${opFilter drvImports}))";
  opBuild = drvs: opRealise (map drvOf drvs);
  buildAnd = drvs: run:
    ''${buildDrvs drvs} > /dev/null && ${run}'';
  buildAndRun = drvs:
    buildAnd drvs "${nix}/bin/nix run ${toString drvs}";
  taskDrvs = builtins.attrValues tasks;
  taskDrvImports = drvImports taskDrvs;
  toNix = val: with builtins; # honestly why not just use from/to json?
    if isString val then ''"${val}"''
    else if typeOf val == "path" then ''${toString val}''
    else if isList val then ''[ ${concatStringsSep " " (map toNix val)} ]''
    else if isAttrs val then ''{
      ${concatStringsSep "\n" (map (key: ''"${key}" = ${toNix val.${key}};'') (attrNames val))}
    }''
    else if isBool val && val then "true" else if isBool then "false"
    else if isInt val || isFloat val then toString val
    else if val == null then "null"
    else throw "unknown nix value ${toString val}";
  cacheInputsOf = drv: with cipkgs.lib; let
    buildInputs = throw "cache.buildInputs unimplemented";
    default = ! isFunction drv.ci.cache or null;
    # TODO: do this recursively over all inputs?
  in optional (drv.ci.cache.enable or default) drv
    ++ optionals (drv.ci.cache.buildInputs or false) buildInputs # TODO: make this true by default?
    ++ optionals (isFunction drv.ci.cache or null) (drv.ci.cache drv)
    ++ concatMap cacheInputsOf (drv.ci.cache.inputs or []);
  cipkgs = config.cipkgs.pkgs;
  sshExecutor = {
    executor
  }: let
  in {
    attrs = {
      nativeBuildInputs = with cipkgs; [ openssh ];
      passAsFile = [ "privateKey" ];
      inherit executor;
      inherit (env) prefix;
      inherit (executor.ci.connectionDetails) port address user;
    };

    name = "ci-ssh";
    buildCommand = ''
      echo "[$address]:$port $(cat $executor/$prefix/sshd_key.pub)" > known_hosts
      CLIENT_KEY=$(mktemp)
      install -m600 $executor/$prefix/$(basename $commandDrv) $CLIENT_KEY
      ssh -i $CLIENT_KEY -o UserKnownHostsFile=$PWD/known_hosts -p $port $user@$address $commandDrv
    '';
  };
  commandExecutor = {
    drv
  , executor
  }: let
    exDrv = cipkgs.stdenvNoCC.mkDerivation (executor.attrs // {
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
  execSsh = {
    commands
  , connectionDetails # address ? "127.0.0.1", port, user
  }: let
    executorFor = executor: drv: commandExecutor {
      inherit drv;
      executor = sshExecutor {
        inherit executor;
      };
    };
    executors = executor: map (executorFor executor) commands;
    commandsExec = with cipkgs.lib; listToAttrs (map (drv:
      nameValuePair (drvOf drv) (map builtins.unsafeDiscardStringContext drv.ci.exec)
    ) commands);
    drv = cipkgs.stdenvNoCC.mkDerivation {
      inherit (env) prefix;

      passAsFile = [ "authorizedKeys" "sshdScript" "sshdConfig" "commandsExec" ];

      name = "ci-ssh-executor";
      passthru = {
        ci = {
          inherit connectionDetails;
        };
      };

      inherit (connectionDetails) port user;
      sshdConfig = ''
        Port @port@
        #UsePrivilegeSeparation no
        PasswordAuthentication no
        AuthorizedKeysCommand /usr/bin/env cat @out@/@prefix@/authorized_keys
        AuthorizedKeysCommandUser @user@
        ChallengeResponseAuthentication no
        ${cipkgs.lib.optionalString cipkgs.hostPlatform.isLinux "UsePAM no"}
      '';

      inherit (cipkgs) openssh;
      inherit (env) runtimeShell coreutils;
      sshdScript = ''
        #!@runtimeShell@
        HOST_KEY=$(@coreutils@/bin/mktemp)
        @coreutils@/bin/install -m600 @out@/@prefix@/sshd_key $HOST_KEY # TODO: remove this after sshd exit!
        @openssh@/bin/sshd -e -f @out@/@prefix@/sshd_config -o "PidFile $EX_PIDFILE" -o "HostKey $HOST_KEY"
      '';

      nativeBuildInputs = with cipkgs; [ openssh jq ];
      commands = map drvOf commands;
      commandsExec = builtins.toJSON commandsExec;
      buildCommand = ''
        mkdir -p $out/$prefix $out/bin
        ssh-keygen -q -N "" -t ed25519 -f $out/$prefix/sshd_key
        for command in $commands; do
          IFS=$'\n' commandExec=($(jq -er ".\"$command\" | .[]" $commandsExec)) # TODO: support quoting these?
          commandKey=$out/$prefix/$(basename $command)
          ssh-keygen -q -N "" -t ed25519 -f $commandKey
          echo "command=\"''${commandExec[*]}\" $(cat $commandKey.pub)"
        done > $out/$prefix/authorized_keys
        substituteAll $sshdConfigPath $out/$prefix/sshd_config
        substituteAll $sshdScriptPath $out/bin/ci-sshd
        chmod +x $out/bin/ci-sshd
        # TODO: could we make it a systemd user service? can you spawn one-off services with systemctl?? I don't really like just randomly forking something in the background of the test script but eh, it can work fine with exit traps or pidfiles to be fair...
      '';
    };
  /*in drvPassthru (drv: {
    meta = drv.meta or {} // {
      ci = drv.meta.ci or {} // {
        executors = executors drv;
      };
    };
  }) drv;*/
  in drv.overrideAttrs (old: {
    passthru = old.passthru or {} // {
      exec = "${drv}/bin/ci-sshd";
      ci = old.passthru.ci or {} // {
        executor = {
          executors = executors drv;
          for = executorFor drv; # TODO: validate command passed is in commands array? otherwise it will break!
        };
      };
    };
  });
  colours = {
    red = ''$'\e[31m''\''';
    green = ''$'\e[32m''\''';
    yellow = ''$'\e[33m''\''';
    blue = ''$'\e[34m''\''';
    magenta = ''$'\e[35m''\''';
    cyan = ''$'\e[36m''\''';
    clear = ''$'\e[0m''\''';
  };
in {
  inherit buildAndRun toNix drvImports opFilter opFilterNoisy opRealise drvOf cacheInputsOf colours execSsh;
  buildTask = task: let
    drv = if builtins.isString task then config.tasks.${task} else task;
  in opBuild [drv];
  exec = {
    shell = ''${buildAndRun [env.shellEnv]} -c ci-shell'';
    dirty = buildAnd [ci-query ci-dirty] (opFilterNoisy taskDrvImports);
    build = buildAnd [ci-query ci-dirty] (opBuildDirty taskDrvImports);
    buildAll = opBuild taskDrvs;
  };
}
