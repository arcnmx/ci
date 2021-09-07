if builtins.pathExists ./lib/default.nix then ./lib else builtins.fetchTarball {
  url = "https://github.com/arcnmx/nixpkgs-lib/archive/383aa67682f72ecda093a1d1398d36c76016e31e.tar.gz";
  sha256 = "1zm02v995n2zgxzq5xdv9hirlp491536189vjccqr50dxq9zhhpy";
}
