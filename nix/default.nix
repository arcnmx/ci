{ configuration
, pkgs ? null
, check ? true
}@args: let
  inherit (builtins.import ./lib/cipkgs.nix) nixpkgsPath;
  #import = (builtins.import ./lib/scope.nix { }).nixPathImport {
  #  nixpkgs = nixpkgsPath;
  #};
  libPath = builtins.import ./lib/lib.nix;
  lib = builtins.import libPath;
in with lib; let
  pkgs'args = { };
  pkgs'path = builtins.tryEval (import <nixpkgs>);
  pkgs =
    if args.pkgs or null == true && pkgs'path.success then pkgs'path.value pkgs'args
    else if args.pkgs or null == null then builtins.import nixpkgsPath pkgs'args
    else args.pkgs;
  pwd = builtins.getEnv "PWD";
  configPath = if builtins.typeOf configuration == "path" then configuration
    else if hasPrefix "/" configuration then /. + configuration
    else if pwd != "" then /. + "${pwd}/${toString configuration}"
    else throw "could not find configuration ${toString configuration}";
  collectFailed = cfg:
  map (x: x.message) (filter (x: !x.assertion) cfg.assertions);
  showWarnings = res: let
    f = w: x: builtins.trace "warning: ${w}" x;
  in fold f res res.config.warnings;
  #nixosModulesPath = pkgs.path + "/nixos/modules";

  rawModule = evalModules {
    modules = [ configPath ] ++ (builtins.import ./modules.nix {
      inherit check pkgs;
    });
    specialArgs = {
      inherit /*nixosModulesPath*/ libPath;
      modulesPath = builtins.toString ./.;
      configPath = toString configPath;
      rootConfigPath = toString configPath;
    };
  };

  module = showWarnings (let
    failed = collectFailed rawModule.config;
    failedStr = concatStringsSep "\n" (map (x: "- ${x}") failed);
  in if failed == []
    then rawModule
    else throw "\nFailed assertions:\n${failedStr}"
  );
in module.config.export // {
  inherit (module) options config;
}
