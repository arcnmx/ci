{ self, env }: let
  mkCiWrapper = { lib, stdenvNoCC }: input: with lib; let
    wrapped = stdenvNoCC.mkDerivation ({
      # a wrapper prevents the input itself from being a build-time dependency for a task
      name = if hasPrefix "ci-" input.name then input.name else "ci-${input.name}";

      inherit input;
      passthru = input.passthru or {} // {
        ci = input.passthru.ci or {} // {
          wrapped = input;
        };
      };

      buildCommand = ''
        # no-op marker for $input
        mkdir -p $out/nix-support
      '';
    } // optionalAttrs (input ? meta) {
      inherit (input) meta;
    });
  in input.ci.wrapped or wrapped;
  mkCiTask = { lib, stdenvNoCC }: with lib; makeOverridable ({
    pname
  , version ? null
  # inputs to the task must all build for the task to succeed.
  # additionally provide them as buildInputs if the task needs to 0w
  , inputs ? []
  , buildCommand ? ""
  , warn ? null
  , skip ? null
  , cache ? null
  , timeout ? null
  , displayName ? null
  , ...
  }@args: let
    wrapInput = mkCiWrapper { inherit lib stdenvNoCC; };

    flattenInputs = inputs:
      if inputs ? ci.inputs then flattenInputs inputs.ci.inputs
      #else if isDerivation inputs && inputs.ci.omit or false != false then [ ]
      else if isDerivation inputs then [ inputs ]
      else if isAttrs inputs then concatMap flattenInputs (attrValues inputs)
      else if isList inputs then concatMap flattenInputs inputs
      else builtins.trace inputs (throw "unsupported inputs");
    inputs = flattenInputs (args.inputs or []);

    isValid = drv: assert isDerivation drv; # TODO: support lists or attrsets of derivations?
      !(drv.meta.broken or false) && (drv.ci.skip or false) == false && (drv.ci.omit or false) == false && drv.meta.available or true;
    allDrvs = drv: [ drv ]
      ++ map (mapTest drv) drv.ci.tests or [];
    mapTest = drv: test: if isFunction test
      then test drv
      else test;
    partitioned = partition isValid inputs;
    validInputs' = concatMap allDrvs partitioned.right;
    mapInput = input: if cache == false then input.overrideAttrs (old: {
      passthru = old.passthru or {} // {
        ci = old.passthru.ci or {} // {
          cache.enable = false;
        };
      };
    }) else if cache == { wrap = true; } || input.ci.cache.wrap or false == true then input.overrideAttrs (old: {
      passthru = old.passthru or {} // {
        ci = old.passthru.ci or {} // {
          inputs = old.passthru.ci.inputs or [] ++ [ (wrapInput input) ];
          cache = {
            enable = true;
            inputs = [ (wrapInput input) ];
          };
        };
      };
    }) else input;
    validInputs = if cache != false then validInputs'
      else map mapInput validInputs';
    skippedInputs = partitioned.wrong; # TODO: note these somewhere in some way?
    wrappedInputs = map wrapInput validInputs; # TODO: possibly want to be able to filter out warn'd inputs so task can still run when they fail?
    warn = args.warn or false || (any (drv: drv.ci.warn or false) inputs); # tasks inherit any `warn` attributes from inputs
    args' = builtins.removeAttrs args [
      "pname" "version" "inputs" "meta" "buildCommand" "warn" "skip" "cache" "timeout" "displayName"
      "passAsFile" "passthru"
    ];
  in stdenvNoCC.mkDerivation ({
    inherit pname version;
    name = "${pname}" + optionalString (version != null) "-${version}";

    wrappedInputs = wrappedInputs;

    preferLocalBuild = true;
    allowSubstitutes = true;
    passAsFile = [ "buildCommand" ] ++ args.passAsFile or [];
    buildCommand = ''
      ${buildCommand}
      touch $out
    '';

    meta = {
      ${mapNullable (_: "name") displayName} = displayName;
      ${mapNullable (_: "timeout") timeout} = timeout;
    } // args.meta or {};

    passthru = args.passthru or {} // {
      inputs = validInputs;
      inputsAll = inputs;
      inputsSkipped = skippedInputs;
      ci = {
        tests = validInputs;
        inherit warn;
        ${mapNullable (_: "skip") skip} = skip;
        ${mapNullable (_: "cache") cache} = if isBool cache then { enable = cache; } else cache;
      } // args.passthru.ci or {};
    };
  } // args'));
  mkCiCommand = { lib, runCommand }: with lib; makeOverridable ({
    pname
  , command
  , warn ? false
  , skip ? null
  , cache ? null
  , displayName ? null
  , timeout ? null
  , tests ? null
  , hostExec ? false
  , ciEnv ? true
  , sha256 ? null
  , ...
  }@args: let
    args' = removeAttrs args [
      "pname" "command" "meta" "passthru" "warn" "skip" "cache" "displayName" "timeout" "tests" "hostExec" "sha256" "ciEnv" "passAsFile"
    ];
    argVars = attrNames args';
    commandPath = "${env.prefix}/run-test";
    command' = if hostExec == true then ''
      mkdir -p $out/${env.prefix}
      {
        cat $commandHeaderPath
        ${optionalString (argVars != []) "declare -p $argVars"}
        cat $commandPath
      } > $out/${commandPath}
      chmod +x $out/${commandPath}
    '' else ''
      source $commandHeaderPath
      mkdir -p $out
      source $commandPath
    '';
    hostExec' = [ "${drv}/${commandPath}" ];
    drv = runCommand pname ({
      preferLocalBuild = true;
      allowSubstitutes = true;

      inherit argVars;
      commandHeader = optionalString ciEnv ''
        #!${env.runtimeShell}
        source ${env.runtimeEnv}/${env.prefix}/source
        ci_env_impure
      '';
      passAsFile = [ "command" "commandHeader" ] ++ args.passAsFile or [];
      inherit command;

      meta = {
        ${mapNullable (_: "name") displayName} = displayName;
        ${mapNullable (_: "timeout") timeout} = timeout;
      } // args.meta or {};

      passthru = args.passthru or {} // {
        ci = {
          inherit warn;
          ${mapNullable (_: "skip") skip} = skip;
          ${mapNullable (_: "cache") cache} = if isBool cache then { enable = cache; } else cache;
          ${mapNullable (_: "tests") tests} = toList tests;
          ${if hostExec == true then "exec" else null} = hostExec';
        } // args.passthru.ci or {};
      };
    } // optionalAttrs (sha256 != null) {
      outputHashAlgo = "sha256";
      outputHash = sha256;
    } // args') command';
  in drv);
in {
  mkCiTask = self.callPackage mkCiTask { };
  mkCiWrapper = self.callPackage mkCiWrapper { };
  mkCiCommand = self.callPackage mkCiCommand { };
  mkCiSystem = {
    name
  , system # as in nixpkgs
  }@args: let
  in {
    inherit name system;

    instantiate = { pkgsPath }: import pkgsPath {
      inherit system;
    };
  };
  # passthru.ci.skip = true; # do not test
  # passthru.ci.omit = true; # do not evaluate
  # passthru.ci.cache = drv: [ drv ]; # inputs to cache for a given drv
  # passthru.ci.cache.enable = false; # always re-run, true is default
  # passthru.ci.cache.buildInputs = true; # cache build inputs
  # passthru.ci.cache.inputs = [...]; # other items to cache with it
  # - consider how this should differ from making a build non-deterministic (input with currentTime or CI build counter env var)
  # passthru.ci.exec = ["script" "and" "args"]; # a test that runs in the host environment (with the associated derivation in scope/PATH):
  # passthru.ci.eval = drv: assert something; true; # a test that checks whether the given expression evaluates to `true` # TODO: implement this
  # - can be impure and use network, caches, etc
  # passthru.ci.inputs = actual derivation to build/test (use to avoid recursing into unsupported attrs, or to build mkShells, etc)
  # passthru.ci.tests = []; # related test derivations, expects a function with a { drv }: argument.
  # passthru.ci.max-silent-time # seconds
  # meta.timeout = seconds; # see https://nixos.org/nixpkgs/manual/#sec-standard-meta-attributes
  # passthru.tests = []; # related test derivations for hydra, idk, ignore?
  # meta.broken, meta.platforms, etc. are obeyed as expected and considered the same as "ci.skip"
}
