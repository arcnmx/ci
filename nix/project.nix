{ config, lib, nixosModulesPath, modulesPath, configPath, rootConfigPath, ... }: with lib; let
  # NOTE: perhaps submodules are the wrong way to go about this, just use evalModules again
  # (mostly saying this because as far as I can tell, there's no way to pass specialArgs on to submodules? I imagine that could be hacked into lib/ though?)
  submodule = imports: types.submodule {
    imports = imports ++ import ./modules.nix {
      inherit (config.bootstrap) pkgs;
      inherit (config._module) check;
    };

    config = {
      _module.args = {
        inherit modulesPath rootConfigPath;
        configPath = mkOptionDefault configPath;
        parentConfigPath = configPath;
      };
    };
  };
  jobModule = { name, ...}: {
    config = {
      parentConfig = config;
      inherit (config) stageId;
      jobId = name;
      jobs = mkForce { }; # jobs only go one level deep!
    };
  };
  stageModule = { name, ...}: {
    config = {
      parentConfig = config;
      stageId = name;
    };
  };
in {
  options = {
    jobId = mkOption {
      type = types.nullOr types.str;
      default = null;
      internal = true;
    };
    stageId = mkOption {
      type = types.nullOr types.str;
      default = null;
      internal = true;
    };
    exportAttr = mkOption {
      type = types.nullOr types.str;
      internal = true;
      default = let
        prefix = if config.parentConfig == null then "" else config.parentConfig.exportAttrDot;
      in if config.jobId != null then "${prefix}job.${config.jobId}"
        else if config.stageId != null then "${prefix}stage.${config.stageId}"
        else null;
    };
    exportAttrDot = mkOption {
      type = types.str;
      internal = true;
      default = if config.exportAttr == null then "" else "${config.exportAttr}.";
    };
    id = mkOption {
      type = types.str;
      default = findFirst (i: i != null) "ci" [ config.jobId config.stageId ];
      internal = true;
    };
    name = mkOption {
      type = types.str;
      default = findFirst (i: i != null) "ci" [ config.jobId config.stageId ];
    };
    parentConfig = mkOption {
      type = types.nullOr types.unspecified;
      default = null;
      internal = true;
    };
    warn = mkOption {
      type = types.bool;
      default = false;
    };
    jobs = mkOption {
      type = types.attrsOf (submodule [ configPath jobModule ]);
      default = { };
    };
    stages = let
      type = types.coercedTo types.path (configPath: {
        imports = [ configPath ];
        config._module.args = {
          inherit configPath;
        };
      }) (submodule [ stageModule ]);
    in mkOption {
      type = types.attrsOf type;
      # TODO: coercedTo types.path
      default = { };
    };
    project = {
      exec = mkOption {
        type = types.attrsOf types.str; # TODO: or lines?
        default = { };
      };
      run = mkOption {
        type = types.attrsOf types.package;
        default = { };
      };
    };
    export.job = mkOption {
      type = types.attrsOf types.unspecified;
    };
    export.stage = mkOption {
      type = types.attrsOf types.unspecified;
    };
  };
  config = {
    export.job = mapAttrs (_: s: s.export) config.jobs;
    export.stage = mapAttrs (_: s: s.export) config.stage;
    lib.ci = {
      inherit (import ./lib/scope.nix { }) nixPathImport;
    };
  };
}
