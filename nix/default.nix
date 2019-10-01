{ configuration
, pkgs ? null
, check ? true
}@args: let
  inherit (builtins.import ./lib/cipkgs.nix) nixpkgsPath;
  import = (builtins.import ./lib/scope.nix { }).nixPathImport {
    nixpkgs = nixpkgsPath;
  };
  pkgs = args.pkgs or (import nixpkgsPath { });
in with pkgs.lib; let
  collectFailed = cfg:
  map (x: x.message) (filter (x: !x.assertion) cfg.assertions);
  showWarnings = res: let
    f = w: x: builtins.trace "warning: ${w}" x;
  in fold f res res.config.warnings;
  nixosModulesPath = pkgs.path + "/nixos/modules";

  rawModule = evalModules {
    modules = [ configuration ] ++ (import ./modules.nix {
      inherit check pkgs nixosModulesPath;
    });
    specialArgs = {
      modulesPath = builtins.toString ./.;
      configPath = toString (/. + configuration);
    };
  };

  module = showWarnings (let
    failed = collectFailed rawModule.config;
    failedStr = concatStringsSep "\n" (map (x: "- ${x}") failed);
  in if failed == []
    then rawModule
    else throw "\nFailed assertions:\n${failedStr}"
  );
in module.config.ci.export // {
  inherit (module) options config;
}
