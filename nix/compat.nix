with builtins; let
  updateFlipped = a: b: b // a;
  remap = { prefix, path }: { ${prefix} = path; };
  prefixed = filter ({ prefix, ... }: prefix != "") nixPath;
  paths = foldl' updateFlipped {} (map remap prefixed);
in mapAttrs (_: import) paths
