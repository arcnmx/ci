{ pkgs, lib, ... }: with lib; {
  ci = {
    url = ".";
    gh-actions = {
      enable = true;
    };
  };
  name = "tests-cache";
  cache.cachix.ci.enable = true;
  tasks.touch.inputs = pkgs.runCommand "touch" {
    inherit system;
  } ''
    echo $system > $out
  '';
}
