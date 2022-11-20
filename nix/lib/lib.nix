if builtins.pathExists ./lib/default.nix then ./lib else builtins.fetchTarball {
  url = "https://github.com/arcnmx/nixpkgs-lib/archive/1778ac429eb4c75bec2b0738b9b022c687a34fda.tar.gz";
  sha256 = "13yn6aay2mwr8k36pq79sv6navkd47219jphs18ckk902l7r108f";
}
