rec {
  nixpkgsSource = { rev, sha256 }: builtins.fetchTarball {
    name = "source";
    url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };
  nixpkgsFor = {
    # pinned nixpkgs evaluations bundled with nix binary releases (https://hydra.nixos.org/project/nix)
    # TODO: check <nix/config.nix> to make sure these actually line up?
    "2.3" = nixpkgsSource {
      rev = "56b84277cc8c52318a99802878b0725b2e34648e";
      sha256 = "0rhpkfcfvszvcga7lcy4zqzchglsnvrzphkz59ifp9ihvmxrq14y";
    };
    "2.2.2" = nixpkgsSource {
      rev = "2296f0fc9559d0b6e08a7c07b25bd0a5f03eebe5";
      sha256 = "197f6glm69717a5pj7bwm57vf1wrgh8nb13sa9qpjkz4803xpzdf";
    };
    "2.2.1" = nixpkgsSource {
      rev = "d26f11d38903768bf10036ce70d67e981056424b";
      sha256 = "16d986r76ps7542mbm63dxiavxw9af08l4ffpjp38lpam2cd9zpp";
    };
    "19.03" = nixpkgsSource {
      # random pinned stable version from 2019-06ish
      rev = "d7752fc0ebf9d49dc47c70ce4e674df024a82cfa";
      sha256 = "1rw4fgnm403yf67lgnvalndqqy6ln6bz1grd6zylrjblyxnhqkmj";
    };
  };
  nixpkgsPath = nixpkgsFor.${builtins.nixVersion} or nixpkgsFor."19.03";
  nixpkgs = args: import nixpkgsPath args;
}
