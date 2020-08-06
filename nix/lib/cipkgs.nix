rec {
  nixpkgsSource = { rev, sha256 }: {
    name = "source";
    url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };
  nixpkgsFor = {
    # pinned nixpkgs evaluations bundled with nix binary releases (https://hydra.nixos.org/project/nix)
    "2.3" = nixpkgsSource {
      rev = "56b84277cc8c52318a99802878b0725b2e34648e";
      sha256 = "0rhpkfcfvszvcga7lcy4zqzchglsnvrzphkz59ifp9ihvmxrq14y";
    };
    "2.3.1" = nixpkgsSource {
      rev = "df7e351af91e6cbf4434e281d35fec39348a5d91";
      sha256 = "19fpg1pya2iziwk10wja69ma65r985zdcd9blkplyg0l1lnn8haq";
    };
    "2.3.2" = nixpkgsSource {
      rev = "87c698a5ca655fe108958eb4bc6ad7a9b8bfcd82";
      sha256 = "1ayipwmgbnf2vggr7jbq5l0vg0ly3g2wmcyajd3a7355g9hys3q3";
    };
    "2.3.3" = nixpkgsSource {
      rev = "4dc0c1761c8dd15e9ddfff793f22dba2a0828986";
      sha256 = "1pw9xfsqfaig1vdmm6a4cgbqdw5bc0by84g7rip53m68p8fa33c5";
    };
    "2.3.7" = nixpkgsSource {
      rev = "0cfa467f8771ca585b3e122806c8337f5025bd92";
      sha256 = "09fp8fvhc1jhaxjabf9nspqxn47lkknkfxp66a09y4bxf9120q18";
    };
    "2.2.1" = nixpkgsSource {
      rev = "d26f11d38903768bf10036ce70d67e981056424b";
      sha256 = "16d986r76ps7542mbm63dxiavxw9af08l4ffpjp38lpam2cd9zpp";
    };
    "2.2.2" = nixpkgsSource {
      rev = "2296f0fc9559d0b6e08a7c07b25bd0a5f03eebe5";
      sha256 = "197f6glm69717a5pj7bwm57vf1wrgh8nb13sa9qpjkz4803xpzdf";
    };
    "19.09" = nixpkgsSource {
      # 19.09 release
      rev = "d5291756487d70bc336e33512a9baf9fa1788faf";
      sha256 = "0mhqhq21y5vrr1f30qd2bvydv4bbbslvyzclhw0kdxmkgg3z4c92";
    };
  };
  nixpkgsUrl = nixpkgsFor.${builtins.nixVersion} or nixpkgsFor."19.09";
  nixpkgsPath = builtins.fetchTarball nixpkgsUrl;
  nixpkgs = args: import nixpkgsPath args;
}
