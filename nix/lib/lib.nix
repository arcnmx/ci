if builtins.pathExists ./lib/default.nix then ./lib else builtins.fetchTarball {
  url = "https://github.com/arcnmx/nixpkgs-lib/archive/4ac4a5e58ac78c00e27afabff0183d0396507c69.tar.gz";
  sha256 = "162qz327f6cmqdxbxwrka9s7fz2gsqrvmfkx0a6n4w5gs7hnjzcb";
}
