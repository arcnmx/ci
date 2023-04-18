if builtins.pathExists ./lib/default.nix then ./lib else builtins.fetchTarball {
  url = "https://github.com/arcnmx/nixpkgs-lib/archive/d21353de66de858fb2998ed76da67a62ccc252dd.tar.gz";
  sha256 = "00kx3agiv5d61mjhw5lc3lq1s0frvy2pz9cs4cs3ghwvz68r057j";
}
