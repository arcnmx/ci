with builtins; let
  toPath = path: if builtins.match "http.*" path != null
    then builtins.fetchTarball path # TODO: include hash if we know it for nixpkgs?
    else path;
  updateFlipped = a: b: b // a;
  remap = { prefix, path }: { ${prefix} = toPath path; };
  prefixed = filter ({ prefix, ... }: prefix != "") nixPath;
  paths = foldl' updateFlipped {} (map remap prefixed);
in mapAttrs (_: import) paths
