{ config, lib, ... }: let
  inherit (builtins) toFile;
  inherit (lib) mkOption isAttrs;
  ty = lib.types;
  toNixValue = v:
    if v == true then "true"
    else if v == false then "false"
    else if isAttrs v then concatMapAttrsToList " " (k: v: "${k}=${v}") v
    else toString v;
  settingsPrimitiveType = ty.oneOf [
    ty.int
    ty.bool
    ty.string
  ];
  settingsType = ty.attrsOf (ty.oneOf [
    (ty.attrsOf settingsPrimitiveType)
    (ty.listOf settingsPrimitiveType)
    settingsPrimitiveType
  ]);
  settingsModule = {
    freeformType = settingsType;
  };
in {
  options = {
    settings = mkOption {
      type = ty.submodule settingsModule;
      default = { };
    };

    configText = mkOption {
      type = ty.lines;
    };
    configFile = mkOption {
      type = ty.package;
      default = toFile "nix.conf" config.configText;
    };
  };
  config = {
    configText = mkMerge (mapAttrsToList (k: v: "${k} = ${toNixValue v}") config.settings);
  };
}
