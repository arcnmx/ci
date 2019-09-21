{
  ciConfig = {
    cache.cachix.ci = { };
  };
  touch = with import <nixpkgs> { }; runCommand "touch" {
    inherit system;
  } ''
    echo $system > $out
  '';
}
