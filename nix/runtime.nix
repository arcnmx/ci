{ env }@args: with env; envBuilder {
  # second stage bootstrap env
  pname = "ci-env";
  packages = builtins.attrValues packages;
}
