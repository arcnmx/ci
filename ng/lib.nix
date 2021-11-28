{
  evalCi = { self, callPackage, lib }: {
    config
  , specialArgs ? { }
  }: let
    inherit (lib) evalModules;
  in evalModules {
    modules = [
      self.nixosModules.ci
      config
    ];
    specialArgs = specialArgs // {
      inherit callPackage;
    };
  };
}
