{ pkgs, config, lib, ... }: with lib; let
  inherit (config.bootstrap) pkgs;
  executor = config.project.executor.drv;
  warn = config.warn;
  flattenInputs = inputs:
    if inputs ? ci.inputs then flattenInputs inputs.ci.inputs
    #else if isDerivation inputs && inputs.ci.omit or false != false then [ ]
    else if isDerivation inputs then [ inputs ]
    else if isAttrs inputs then concatMap flattenInputs (attrValues inputs)
    else if isList inputs then concatMap flattenInputs inputs
    else builtins.trace inputs (throw "unsupported inputs");
  isValid = drv: assert isDerivation drv; # TODO: support lists or attrsets of derivations?
    !(drv.meta.broken or false) && (drv.ci.skip or false) == false && (drv.ci.omit or false) == false && drv.meta.available or true;
  mapInput = cache: input: if ! cache.enable then input.overrideAttrs (old: {
    passthru = old.passthru or {} // {
      allowSubstitutes = false; # this needs to be part of the derivation doesn't it :(
      ci = old.passthru.ci or {} // {
        cache.enable = false;
      };
    };
  }) else if cache.wrap || input.ci.cache.wrap or false == true then input.overrideAttrs (old: {
    passthru = old.passthru or {} // {
      ci = old.passthru.ci or {} // {
        inputs = old.passthru.ci.inputs or [] ++ [ (pkgs.ci.wrapper input) ];
        cache = {
          enable = true;
          inputs = [ (pkgs.ci.wrapper input) ];
        };
      };
    };
  }) else input;
  taskType = types.submodule ({ name, config, ... }: {
    options = {
      id = mkOption {
        type = types.str;
        default = "ci-task-${name}";
      };
      name = mkOption {
        type = types.nullOr types.str;
        default = name;
      };
      args = mkOption {
        type = types.attrsOf types.unspecified;
        default = { };
      };
      inputs = let
        #inputType = types.package;
        inputType = types.unspecified; # have you seen flattenInputs?? it doesn't require derivations wow
        type = types.listOf inputType;
        fudge = types.coercedTo inputType singleton type;
      in mkOption {
        type = fudge;
        default = [ ];
      };
      preBuild = mkOption {
        type = types.lines;
        default = "";
      };
      buildCommand = mkOption {
        type = types.lines;
        default = "";
      };
      warn = mkOption {
        type = types.bool;
        default = warn || any (i: i.ci.warn or false) config.inputs;
      };
      skip = mkOption {
        type = types.either types.bool types.str;
        default = false;
      };
      timeoutSeconds = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
      };
      cache = {
        enable = mkEnableOption "cache build results" // { default = true; };
        wrap = mkEnableOption "cache whether a build succeeds and not the output";
        inputs = mkOption {
          type = types.listOf types.package;
          default = [ ];
        };
        # TODO: other attrs that are valid here?
      };
      drv = mkOption {
        type = types.package;
        internal = true;
      };
      internal.inputs = {
        all = mkOption {
          type = types.listOf types.package;
          internal = true;
        };
        valid = mkOption {
          type = types.listOf types.package;
          internal = true;
        };
        tests = mkOption {
          type = types.listOf types.package;
          internal = true;
        };
        skipped = mkOption {
          type = types.listOf types.package;
          internal = true;
        };
        impure = mkOption {
          type = types.listOf types.package;
          internal = true;
        };
        pure = mkOption {
          type = types.listOf types.package;
          internal = true;
        };
        wrapped = mkOption {
          type = types.listOf types.package;
          internal = true;
        };
        wrappedImpure = mkOption {
          type = types.listOf types.package;
          internal = true;
        };
      };
    };
    config = {
      internal.inputs = let
        partitioned = partition isValid config.internal.inputs.all;
        inputs = map (mapInput config.cache) (config.internal.inputs.valid ++ config.internal.inputs.tests);
        partitioned'impure = partition (d: d ? ci.exec) inputs;
        mapTest = drv: test: if isFunction test
          then test drv
          else test;
      in {
        all = flattenInputs config.inputs;
        skipped = partitioned.wrong;
        valid = partitioned.right;
        tests = concatMap (d: map (mapTest d) d.ci.tests or []) config.internal.inputs.valid;
        impure = partitioned'impure.right;
        pure = partitioned'impure.wrong;
        wrapped = map pkgs.ci.wrapper partitioned'impure.wrong;
        wrappedImpure = map executor.ci.executor.for config.internal.inputs.impure;
        # TODO: possibly want to be able to filter out warn'd inputs so task can still run when they fail?
      };
      drv = pkgs.stdenvNoCC.mkDerivation {
        name = config.id;

        inherit (config.internal.inputs) wrapped;
        inherit (config.internal.inputs) wrappedImpure;

        preferLocalBuild = true;
        allowSubstitutes = true;
        passAsFile = [ "buildCommand" ] ++ config.args.passAsFile or [];
        buildCommand = ''
          ${config.buildCommand}
          mkdir -p $out/nix-support
          echo $wrapped $wrappedImpure > $out/nix-support/ci-task
        '';

        meta = {
          inherit (config) name;
          ${mapNullable (_: "timeout") config.timeoutSeconds} = config.timeoutSeconds;
        };
        passthru = config.args.passthru or {} // {
          inputs = config.internal.inputs.valid;
          inputsAll = config.internal.inputs.all;
          inputsSkipped = config.internal.inputs.skipped;
          ci = {
            tests = config.internal.inputs.valid;
            inherit (config) warn skip cache;
          } // config.args.passthru.ci or {};
        };
      };
    };
  });
in {
  options = {
    project = {
      executor = {
        connectionDetails = mkOption {
          type = types.attrsOf types.unspecified;
          default = {
          };
        };
        drv = mkOption {
          type = types.nullOr types.package;
          internal = true;
        };
      };
    };
    tasks = mkOption {
      type = types.attrsOf taskType;
      default = { };
    };
  };
  config.project.executor = {
    drv = let
      commands = concatLists (mapAttrsToList (_: t: t.internal.inputs.impure) config.tasks);
    in mkOptionDefault (if commands == [] then null else config.lib.ci.execSsh {
      inherit (config.project.executor) connectionDetails;
      inherit commands;
    });
    connectionDetails = mapAttrs (_: mkOptionDefault) {
      address = "127.0.0.1";
      user = builtins.getEnv "USER";
      port = if builtins.getEnv "CI_PORT" == ""
        then 50650 # u-umm
        else builtins.getEnv "CI_PORT";
    };
  };
  config.lib.ci = {
    inherit (import ./lib/impure.nix { inherit config lib; }) hostPath hostDep;
  };
}
