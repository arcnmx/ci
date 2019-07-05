{
  ciConfig = {
    cache.cachix.arc = { };
  };
  touch = with import <nixpkgs> { }; runCommand "touch" {
    inherit system;
  } ''
    echo $system > $out
  '';
}
