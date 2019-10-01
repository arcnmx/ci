{ lib, ... }: with lib; {
  options = {
    lib = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
    };
  };
}
