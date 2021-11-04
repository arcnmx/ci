{ pkgs, ... }: {
  name = "tests-stages";
  ci = {
    url = ".";
    gh-actions.enable = true;
  };
  tasks.dummy.inputs = pkgs.ci.command {
    name = "dummy";
    command = "true";
  };
  stages.another = { pkgs, ... }: {
    tasks.something.inputs = pkgs.ci.command {
      name = "dummy2";
      command = "true";
    };
  };
}
