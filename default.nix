{ ciVersion ? 4, ... }@args: let
  default = throw "TODO";
  backcompat = import ./backcompat args;
  warning = ''
    WARN: using <ci/backcompat>; consider explicitly setting `ci.version = "v0.4"` or updating to 0.5
  '';
in if ciVersion == 4
  then builtins.trace warning backcompat
  else default
