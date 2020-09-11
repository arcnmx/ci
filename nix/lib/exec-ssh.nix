{ lib, config }: with lib; let
  inherit (config.bootstrap.pkgs.buildPackages) pkgs;
  sshdkey = pkgs.stdenvNoCC.mkDerivation {
    name = "ci-ssh-serverkey";

    nativeBuildInputs = [ pkgs.openssh ];

    outputs = [ "out" "priv" ];
    buildCommand = ''
      ssh-keygen -q -N "" -t ed25519 -f sshd_key
      mv sshd_key.pub $out
      mv sshd_key $priv
    '';
  };
  commandKeyFor = command: pkgs.stdenvNoCC.mkDerivation {
    name = "ci-ssh-commandkey";

    nativeBuildInputs = [ pkgs.openssh ];

    commandName = command.name; # TODO: hash more properties here

    outputs = [ "out" "priv" ];
    buildCommand = ''
      ssh-keygen -q -N "" -t ed25519 -f ssh_key
      mv ssh_key.pub $out
      mv ssh_key $priv
    '';
  };
  sshExecutor = {
    drv
  , executor
  }: let
    tty = true;
  in {
    attrs = {
      nativeBuildInputs = [ pkgs.openssh ];
      inherit sshdkey;
      sshkey = (commandKeyFor drv).priv;
      inherit (executor.ci.connectionDetails) port address user;
    };

    name = "ci-ssh";
    buildCommand = ''
      echo "[$address]:$port $(cat $sshdkey)" > known_hosts
      CLIENT_KEY=$(mktemp)
      install -m600 $sshkey $CLIENT_KEY
      ssh ${optionalString tty "-t -t"} -q -F none -i $CLIENT_KEY -o UserKnownHostsFile=$PWD/known_hosts -o GlobalKnownHostsFile=/dev/null -p $port $user@$address false
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
        inherit drv;
        inherit executor;
      };
    };
    executors = executor: map (executorFor executor) commands;
    commandsExec = listToAttrs (map (drv:
      nameValuePair (config.lib.ci.drvOf drv) {
        exec = map builtins.unsafeDiscardStringContext drv.ci.exec;
        key = commandKeyFor drv;
      }
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

      sshdkey = sshdkey.priv;
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
        @coreutils@/bin/install -m600 @sshdkey@ $HOST_KEY # TODO: remove this after sshd exit!
        @openssh@/bin/sshd -e -f @out@/@prefix@/sshd_config -h $HOST_KEY -o "PidFile $EX_PIDFILE"
      '';

      nativeBuildInputs = with pkgs; [ openssh jq ];
      commands = map config.lib.ci.drvOf commands;
      commandsExec = builtins.toJSON commandsExec;
      buildCommand = ''
        mkdir -p $out/$prefix $out/bin
        for command in $commands; do
          IFS=$'\n' commandExec=($(jq -er ".\"$command\".exec | .[]" $commandsExecPath)) # TODO: support quoting these?
          commandKey=$(jq -er ".\"$command\".key" $commandsExecPath)
          echo "command=\"''${commandExec[*]}\" $(cat $commandKey)"
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
