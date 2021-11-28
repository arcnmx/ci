{
  inputs = {
    nixpkgs.url = "nixpkgs-lib";
    flakes = {
      url = "flakes";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { flakes, ... }@inputs: flakes {
    inherit inputs;
    name = "ci";
    lib = import ./ng/lib.nix;
    nixosModules = {
      ci = self.flakes.callPackage ./ng/modules/default.nix;
    };
  };
}
