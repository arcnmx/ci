{ ... }: let
  nixPathList = nixPathAttrs: let 
    nixPath = {
      # never really makes sense to omit <nix>?
      nix = <nix>;
    } // nixPathAttrs;
  in builtins.map (prefix: {
    inherit prefix;
    path = toString nixPath.${prefix};
  }) (builtins.attrNames nixPath);
  nixPathScopedImport = nixPath: let
    scope = {
      __nixPath = nixPath;
      import = builtins.scopedImport scope;
    };
  in scope.import;
in {
  inherit nixPathScopedImport nixPathList;
}
