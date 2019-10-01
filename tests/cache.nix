{ pkgs, lib, ... }: with lib; {
  ci = {
    project.name = "tests-cache";
    url = ".";
    gh-actions = {
      enable = true;
    };
    env.cache.cachix.ci.enable = true;
    project.tasks.touch.inputs = pkgs.runCommand "touch" {
      inherit system;
    } ''
      echo $system > $out
    '';
  };
}
