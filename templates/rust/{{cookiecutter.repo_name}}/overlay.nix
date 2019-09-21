self: super: {
  {{cookiecutter.project_slug}} = self.callPackage ./derivation.nix { };
}
