{ pkgs ? import <nixpkgs> { } }: with pkgs; {
  example = runCommand "example" { } ''
    touch $out
  '';
}
