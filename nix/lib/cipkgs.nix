rec {
  getNixpkgsHashFor = { version }: let
    # nix eval -f nix/lib/cipkgs.nix getNixpkgsHashFor.sourceInfo --argstr version 2.10.3
    nix = builtins.getFlake "github:NixOS/nix/${version}";
  in {
    sourceInfo = {
      inherit (nix.inputs.nixpkgs.sourceInfo) rev narHash;
    };
  };
  nixpkgsSource = { rev, sha256 }: {
    name = "source";
    url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  };
  nixpkgsFor = {
    # pinned nixpkgs evaluations bundled with nix binary releases (https://github.com/NixOS/nix/blob/master/flake.lock)
    "2.21." = nixpkgsFor."2.20.0";
    "2.21.0" = nixpkgsSource {
      rev = "b550fe4b4776908ac2a861124307045f8e717c8e";
      sha256 = "sha256-7kkJQd4rZ+vFrzWu8sTRtta5D1kBG0LSRYAfhtmMlSo=";
    };
    "2.20." = nixpkgsFor."2.20.5";
    "2.20.5" = nixpkgsFor."2.20.4";
    "2.20.4" = nixpkgsFor."2.20.3";
    "2.20.3" = nixpkgsFor."2.20.2";
    "2.20.2" = nixpkgsFor."2.20.1";
    "2.20.1" = nixpkgsFor."2.20.0";
    "2.20.0" = nixpkgsSource {
      rev = "a1982c92d8980a0114372973cbdfe0a307f1bdea";
      sha256 = "sha256-K5eJHmL1/kev6WuqyqqbS1cdNnSidIZ3jeqJ7GbrYnQ=";
    };
    "2.19." = nixpkgsFor."2.19.3";
    "2.19.4" = nixpkgsFor."2.19.3";
    "2.19.3" = nixpkgsSource {
      rev = "9ba29e2346bc542e9909d1021e8fd7d4b3f64db0";
      sha256 = "sha256-/nqLrNU297h3PCw4QyDpZKZEUHmialJdZW2ceYFobds=";
    };
    "2.19.2" = nixpkgsFor."2.19.1";
    "2.19.1" = nixpkgsFor."2.19.0";
    "2.19.0" = nixpkgsSource {
      rev = "9eb24edd6a0027fed010ccfe300a9734d029983c";
      sha256 = "sha256-nsQo2/mkDUFeAjuu92p0dEqhRvHHiENhkKVIV1y0/Oo=";
    };
    "2.18." = nixpkgsFor."2.18.2";
    "2.18.2" = nixpkgsSource {
      rev = "9ba29e2346bc542e9909d1021e8fd7d4b3f64db0";
      sha256 = "sha256-/nqLrNU297h3PCw4QyDpZKZEUHmialJdZW2ceYFobds=";
    };
    "2.18.1" = nixpkgsSource {
      rev = "31ed632c692e6a36cfc18083b88ece892f863ed4";
      sha256 = "sha256-CJz71xhCLlRkdFUSQEL0pIAAfcnWFXMzd9vXhPrnrEg=";
    };
    "2.18.0" = nixpkgsSource {
      rev = "a3d30b525535e3158221abc1a957ce798ab159fe";
      sha256 = "sha256-trXDytVCqf3KryQQQrHOZKUabu1/lB8/ndOAuZKQrOE=";
    };
    "2.17." = nixpkgsFor."2.17.2";
    "2.17.2" = nixpkgsFor."2.17.1";
    "2.17.1" = nixpkgsFor."2.17.0";
    "2.17.0" = nixpkgsFor."2.16.1";
    "2.16." = nixpkgsFor."2.16.3";
    "2.16.3" = nixpkgsFor."2.16.2";
    "2.16.2" = nixpkgsFor."2.16.1";
    "2.16.1" = nixpkgsFor."2.16.0";
    "2.16.0" = nixpkgsFor."2.15.1";
    "2.15." = nixpkgsFor."2.15.3";
    "2.15.3" = nixpkgsFor."2.15.2";
    "2.15.2" = nixpkgsFor."2.15.1";
    "2.15.1" = nixpkgsFor."2.15.0";
    "2.15.0" = nixpkgsFor."2.14.1";
    "2.14." = nixpkgsFor."2.14.1";
    "2.14.1" = nixpkgsFor."2.14.0";
    "2.14.0" = nixpkgsFor."2.13.3";
    "2.13." = nixpkgsFor."2.13.6";
    "2.13.6" = nixpkgsFor."2.13.5";
    "2.13.5" = nixpkgsFor."2.13.4";
    "2.13.4" = nixpkgsFor."2.13.3";
    "2.13.3" = nixpkgsFor."2.13.2";
    "2.13.2" = nixpkgsFor."2.13.1";
    "2.13.1" = nixpkgsFor."2.13.0";
    "2.13.0" = nixpkgsSource {
      rev = "04a75b2eecc0acf6239acf9dd04485ff8d14f425";
      sha256 = "sha256-jy1LB8HOMKGJEGXgzFRLDU1CBGL0/LlkolgnqIsF0D8=";
    };
    "2.12." = nixpkgsFor."2.12.1";
    "2.12.1" = nixpkgsFor."2.12.0";
    "2.12.0" = nixpkgsFor."2.11.1";
    "2.11." = nixpkgsFor."2.11.1";
    "2.11.1" = nixpkgsFor."2.11.0";
    "2.11.0" = nixpkgsFor."2.10.3";
    "2.10." = nixpkgsFor."2.10.3";
    "2.10.3" = nixpkgsFor."2.10.2";
    "2.10.2" = nixpkgsSource {
      rev = "365e1b3a859281cf11b94f87231adeabbdd878a2";
      sha256 = "sha256-G++2CJ9u0E7NNTAi9n5G8TdDmGJXcIjkJ3NF8cetQB8=";
    };
    "2.10.1" = nixpkgsFor."2.10.0";
    "2.10.0" = nixpkgsSource {
      rev = "2fa57ed190fd6c7c746319444f34b5917666e5c1";
      sha256 = "sha256-ZaqFFsSDipZ6KVqriwM34T739+KLYJvNmCWzErjAg7c=";
    };
    "2.9.2" = nixpkgsFor."2.9.0";
    "2.9.1" = nixpkgsFor."2.9.0";
    "2.9.0" = nixpkgsFor."2.8.1";
    "2.8.1" = nixpkgsFor."2.8.0";
    "2.8.0" = nixpkgsSource {
      rev = "530a53dcbc9437363471167a5e4762c5fcfa34a1";
      sha256 = "sha256-y53N7TyIkXsjMpOG7RhvqJFGDacLs9HlyHeSTBioqYU=";
    };
    "2.7.0" = nixpkgsFor."2.6.1";
    "2.6.1" = nixpkgsFor."2.6.0";
    "2.6.0" = nixpkgsFor."2.5.1";
    "2.5.1" = nixpkgsFor."2.5.0";
    "2.5.0" = nixpkgsFor."2.4";
    "2.4" = nixpkgsSource {
      rev = "82891b5e2c2359d7e58d08849e4c89511ab94234";
      sha256 = "sha256-d127FIvGR41XbVRDPVvozUPQ/uRHbHwvfyKHwEt5xFM=";
    };
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
    "2.3.8" = nixpkgsSource {
      rev = "afcf35320d8cdce3f569f611819c302c1b724609";
      sha256 = "1ls88988mpyapgr5plky1bavr1ibi3qpl1m2jdx39r35sjlwb83q";
    };
    "2.3.9" = nixpkgsSource {
      rev = "d488daf8504ef1838c6b89f7add9bf370757afe4";
      sha256 = "04rpvdn4s81d7dqcrv2v1qd7yx2n65l9fgc2m1258dcmjqbzv9ah";
    };
    "2.3.10" = nixpkgsSource {
      rev = "929768261a3ede470eafb58d5b819e1a848aa8bf";
      sha256 = "0zi54vbfi6i6i5hdd4v0l144y1c8rg6hq6818jjbbcnm182ygyfa";
    };
    "2.3.11" = nixpkgsSource {
      rev = "1db42b7fe3878f3f5f7a4f2dc210772fd080e205";
      sha256 = "05k9y9ki6jhaqdhycnidnk5zrdzsdammbk5lsmsbz249hjhhgcgh";
    };
    "2.3.12" = nixpkgsSource {
      rev = "1db42b7fe3878f3f5f7a4f2dc210772fd080e205";
      sha256 = "05k9y9ki6jhaqdhycnidnk5zrdzsdammbk5lsmsbz249hjhhgcgh";
    };
    "2.3.13" = nixpkgsSource {
      rev = "0ccd0d91361dc42dd32ffcfafed1a4fc23d1c8b4";
      sha256 = "0dmwi3r1hsv3f11pzf0qmaw5b7w4bncrjypiwfc8sym5bvxb2lcz";
    };
    "2.3.14" = nixpkgsSource {
      rev = "806c01c9f9945dcd63f6daea8f12a787fbb54dd2";
      sha256 = "0d7sr35yb7z13c6940xpk0ngjs1avpvwjhgbhfwxy6zsmhwi2m2z";
    };
    "2.3.15" = nixpkgsSource {
      rev = "ccd782596c1fdd82ec79ed16707bb117cd9d5d11";
      sha256 = "0sxf09v04ldddx2n87zhxw4lvc2hw068pqwad7c5c0xl6jc99dx1";
    };
    "2.3.16" = nixpkgsSource {
      rev = "49017a1c5ac37461144d3b2a6efab02b87bdf066";
      sha256 = "0pm93801rh70cy43gpi3mamdk19cxf9fdnl98v8hf8bvn0f2vz6j";
    };
    "2.3.17" = nixpkgsSource {
      rev = "022caabb5f2265ad4006c1fa5b1ebe69fb0c3faf";
      sha256 = "sha256-lkA5X3VNMKirvA+SUzvEhfA7XquWLci+CGi505YFAIs=";
    };
    "2.3.18" = nixpkgsSource {
      rev = "9b19f5e77dd906cb52dade0b7bd280339d2a1f3d";
      sha256 = "sha256-rCIsyE80jgiOU78gCWN3A0wE0tR2GI5nH6MlS+HaaSQ=";
    };
    "2.2.1" = nixpkgsSource {
      rev = "d26f11d38903768bf10036ce70d67e981056424b";
      sha256 = "16d986r76ps7542mbm63dxiavxw9af08l4ffpjp38lpam2cd9zpp";
    };
    "2.2.2" = nixpkgsSource {
      rev = "2296f0fc9559d0b6e08a7c07b25bd0a5f03eebe5";
      sha256 = "197f6glm69717a5pj7bwm57vf1wrgh8nb13sa9qpjkz4803xpzdf";
    };
    "21.11" = nixpkgsSource {
      # 21.11 release
      rev = "a7ecde854aee5c4c7cd6177f54a99d2c1ff28a31";
      sha256 = "162dywda2dvfj1248afxc45kcrg83appjd0nmdb541hl7rnncf02";
    };
    "22.05" = nixpkgsSource {
      # 22.05 release
      rev = "ce6aa13369b667ac2542593170993504932eb836";
      sha256 = "0d643wp3l77hv2pmg2fi7vyxn4rwy0iyr8djcw1h5x72315ck9ik";
    };
    "22.11" = nixpkgsSource {
      # 22.11 release
      rev = "4d2b37a84fad1091b9de401eb450aae66f1a741e";
      sha256 = "11w3wn2yjhaa5pv20gbfbirvjq6i3m7pqrq2msf0g7cv44vijwgw";
    };
    "23.05" = nixpkgsSource {
      # 23.05 release
      rev = "4ecab3273592f27479a583fb6d975d4aba3486fe";
      sha256 = "10wn0l08j9lgqcw8177nh2ljrnxdrpri7bp0g7nvrsn9rkawvlbf";
    };
    "23.11" = nixpkgsSource {
      # 23.11 release
      rev = "057f9aecfb71c4437d2b27d3323df7f93c010b7e";
      sha256 = "1ndiv385w1qyb3b18vw13991fzb9wg4cl21wglk89grsfsnra41k";
    };
  };
  nixpkgsUrl = nixpkgsFor.${builtins.nixVersion} or nixpkgsFor.${builtins.substring 0 5 builtins.nixVersion} or nixpkgsFor."23.11";
  nixpkgsPath = builtins.fetchTarball nixpkgsUrl;
  nixpkgs = args: import nixpkgsPath args;
}
