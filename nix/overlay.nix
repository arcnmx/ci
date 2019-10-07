self: super: let
  inherit (import ./global.nix) prefix;
  ciWrapper = { lib, stdenvNoCC }: input: with lib; let
    wrapped = stdenvNoCC.mkDerivation ({
      # a wrapper prevents the input itself from being a build-time dependency for a task
      name = if hasPrefix "ci-" input.name then input.name else "ci-${input.name}";
      preferLocalBuild = true;
      allowSubstitutes = true;

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
  ciCommand = { lib, stdenvNoCC, config }: with lib; makeOverridable ({
    name
  , command
  , stdenv ? stdenvNoCC
  , warn ? false
  , skip ? null
  , cache ? null
  , displayName ? null
  , timeout ? null
  , tests ? null
  , impure ? false
  , environment ? []
  , ciEnv ? true
  , sha256 ? null
  , ...
  }@args: let
    args' = removeAttrs args [
      "name" "command" "meta" "passthru" "warn" "skip" "cache" "displayName" "timeout" "tests" "impure" "sha256" "ciEnv" "passAsFile" "environment"
    ];
    argVars = attrNames args' ++ environment;
    commandPath = "${prefix}/run-test";
    # TODO: nativeBuildInputs should work with impure commands!
    command' = if impure == true then ''
      mkdir -p $out/${prefix}
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
    hostExec = [ "${drv}/${commandPath}" ];
    drv = stdenv.mkDerivation ({
      inherit name;
      preferLocalBuild = true;
      allowSubstitutes = true;

      buildCommand = command';

      inherit argVars;
      commandHeader = optionalString ciEnv ''
        #!${self.buildPackages.runtimeShell}
        source ${config.export.env.test}/${prefix}/source
        ci_env_impure
      '';
      passAsFile = [ "buildCommand" "command" "commandHeader" ] ++ args.passAsFile or [];
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
          ${if impure == true then "exec" else null} = hostExec;
        } // args.passthru.ci or {};
      };
    } // optionalAttrs (sha256 != null) {
      outputHashAlgo = "sha256";
      outputHash = sha256;
    } // genAttrs environment builtins.getEnv // args');
  in drv);
in {
  ci = super.lib.makeExtensible (cself: {
    wrapper = self.callPackage ciWrapper { };
    command = self.callPackage ciCommand { inherit (cself) config; };
    commandCC = cself.command.override { stdenvNoCC = self.stdenv; };
  });
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
