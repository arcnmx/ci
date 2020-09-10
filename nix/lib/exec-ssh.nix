{ lib, config }: with lib; let
  inherit (config.bootstrap.pkgs.buildPackages) pkgs;
  sshExecutor = {
    executor
  }: let
  in {
    attrs = {
      nativeBuildInputs = with pkgs; [ openssh ];
      passAsFile = [ "privateKey" ];
      inherit executor;
      inherit (import ../global.nix) prefix;
      inherit (executor.ci.connectionDetails) port address user;
    };

    name = "ci-ssh";
    buildCommand = ''
      echo "[$address]:$port $(cat $executor/$prefix/sshd_key.pub)" > known_hosts
      CLIENT_KEY=$(mktemp)
      install -m600 $executor/$prefix/$(basename $commandDrv) $CLIENT_KEY
      ssh -F none -i $CLIENT_KEY -o UserKnownHostsFile=$PWD/known_hosts -o GlobalKnownHostsFile=/dev/null -p $port $user@$address $commandDrv
    '';
  };
in {
  execSsh = {
    commands
  , connectionDetails
  }: let
    executorFor = executor: drv: config.lib.ci.commandExecutor {
      inherit drv;
      executor = sshExecutor {
        inherit executor;
      };
    };
    executors = executor: map (executorFor executor) commands;
    commandsExec = listToAttrs (map (drv:
      nameValuePair (config.lib.ci.drvOf drv) (map builtins.unsafeDiscardStringContext drv.ci.exec)
    ) commands);
    drv = pkgs.stdenvNoCC.mkDerivation {
      inherit (import ../global.nix) prefix;

      passAsFile = [ "authorizedKeys" "sshdScript" "sshdConfig" "commandsExec" ];

      name = "ci-ssh-executor";
      passthru = {
        ci = {
          inherit connectionDetails;
        };
      };

      inherit (connectionDetails) address port user;
      sshdConfig = ''
        ListenAddress @address@
        Port @port@
        #UsePrivilegeSeparation no
        PasswordAuthentication no
        AuthorizedKeysFile @out@/@prefix@/authorized_keys
        StrictModes no
        ChallengeResponseAuthentication no
        ${optionalString pkgs.hostPlatform.isLinux "UsePAM no"}
      '';

      inherit (pkgs) openssh;
      inherit (config.bootstrap.packages) coreutils;
      inherit (config.bootstrap) runtimeShell;
      sshdScript = ''
        #!@runtimeShell@
        HOST_KEY=$(@coreutils@/bin/mktemp)
        @coreutils@/bin/install -m600 @out@/@prefix@/sshd_key $HOST_KEY # TODO: remove this after sshd exit!
        @openssh@/bin/sshd -e -f @out@/@prefix@/sshd_config -o "PidFile $EX_PIDFILE" -o "HostKey $HOST_KEY"
      '';

      nativeBuildInputs = with pkgs; [ openssh jq ];
      commands = map config.lib.ci.drvOf commands;
      commandsExec = builtins.toJSON commandsExec;
      buildCommand = ''
        mkdir -p $out/$prefix $out/bin
        ssh-keygen -q -N "" -t ed25519 -f $out/$prefix/sshd_key
        for command in $commands; do
          IFS=$'\n' commandExec=($(jq -er ".\"$command\" | .[]" $commandsExecPath)) # TODO: support quoting these?
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
}
