{ lib, rustPlatform, nix-gitignore }: with lib; let
  manifest = builtins.fromTOML ./Cargo.toml;
  package = rustPlatform.buildRustPackage {
    pname = manifest.package.name;
    version = manifest.package.version;
    src = let
      nixignore = ''
        /ci/
      '';
    in nix-gitignore.gitignoreSourcePure [./.gitignore nixignore] ./;
    cargoSha256 = fakeSha256;

    doCheck = false;
    passthru.ci = {
      tests = [ cargoTest integrationTest ];
    };
  };
  # TODO: generate test list? Replicate Cargo behaviour (list from Cargo.toml, plus tests/*.rs)
  # - this would be good to move into rust/build-support/crate.nix *hinthint*
  # - inability to share cache/deps will make this suck without going full buildRustCrate :(
  cargoTest = package.overrideAttrs (old: {
    name = "${old.name}-test";
    buildPhase = "true";
    doCheck = true;
  });
  integrationTest = runCommand "${package.name}-install-test" {
    nativeBuildInputs = package; # NOTE: this will not work as expected without using buildPackages?
  } ''
    false # TODO: run binaries?
  '';
in package
