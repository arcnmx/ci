{ pkgs ? import <nixpkgs> { } }: with pkgs.lib; let
  #systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" ]
  #systems = [ builtins.currentSystem ];
  systems = [ "x86_64-linux" "x86_64-darwin" ];
  nix = pkgs.nixStable;
  binaryTarball = { nix, cacert, ext ? ".tar.gz", pipe ? "${pkgs.gzip}/bin/gzip -c9" }: pkgs.runCommand "nix-binary-tarball-${nix.version}${ext}" rec {
    inherit nix cacert;
    inherit (nix) version;
    nixSrc = pkgs.stdenvNoCC.mkDerivation {
      pname = "nix-src";
      inherit (nix) src version;
      buildCommand = ''
        unpackPhase
        cp -a $sourceRoot $out
      '';
    };
    installerClosureInfo = pkgs.closureInfo { rootPaths = [ nix cacert ]; };
    nixSystem = nix.stdenv.hostPlatform.system;
    inherit ext pipe;
    dir = "nix-${version}-${nixSystem}";
  } ''
    cp $installerClosureInfo/registration $TMPDIR/reginfo
    substitute $nixSrc/scripts/install-nix-from-closure.sh $TMPDIR/install
    substitute $nixSrc/scripts/install-darwin-multi-user.sh $TMPDIR/install-darwin-multi-user.sh
    substitute $nixSrc/scripts/install-systemd-multi-user.sh $TMPDIR/install-systemd-multi-user.sh
    substitute $nixSrc/scripts/install-multi-user.sh $TMPDIR/install-multi-user
    chmod +x $TMPDIR/install
    chmod +x $TMPDIR/install-darwin-multi-user.sh
    chmod +x $TMPDIR/install-systemd-multi-user.sh
    chmod +x $TMPDIR/install-multi-user
    fn=$out/$dir$ext
    mkdir -p $out/nix-support
    echo "file binary-dist $fn" >> $out/nix-support/hydra-build-products
    tar -cv -f $fn \
      -I "$pipe" \
      --owner=0 --group=0 --mode=u+rw,uga+r \
      --absolute-names \
      --hard-dereference \
      --transform "s,$TMPDIR/install,$dir/install," \
      --transform "s,$TMPDIR/reginfo,$dir/.reginfo," \
      --transform "s,$NIX_STORE,$dir/store,S" \
      $TMPDIR/install $TMPDIR/install-darwin-multi-user.sh \
      $TMPDIR/install-systemd-multi-user.sh \
      $TMPDIR/install-multi-user $TMPDIR/reginfo \
      $(cat $installerClosureInfo/store-paths)
  '';
  binaryTarballs = genAttrs systems (system: makeOverridable binaryTarball { inherit (import pkgs.path { inherit system; }) nix cacert; });
in binaryTarballs
