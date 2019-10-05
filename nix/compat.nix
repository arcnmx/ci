with builtins; let
  # TODO: prefixless paths can be supported using readDir, or use the logic nix does:
  # 1. generate keys from the explicit prefixes
  # 2. search prefixless paths first before actually importing the explicit key
  toPath = path: if builtins.match "http.*" path != null
    then builtins.fetchTarball path # TODO: include hash if we know it for nixpkgs?
    else path;
  updateFlipped = a: b: b // a; # TODO: overrides should only happen if the path is invalid, store a list and try in order!
  remap = { prefix, path }: { ${prefix} = toPath path; };
  prefixed = filter ({ prefix, ... }: prefix != "") nixPath;
  paths = foldl' updateFlipped {} (map remap prefixed);
in mapAttrs (_: import) paths
