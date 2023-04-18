{ ... }@args: {
  ciRepoInfo = rec {
    latestVersion = true;
    version = "0.5";
    releaseName = "master";
    releaseRef = "refs/tags/v${version}";
    devBranch = "v${version}-dev";
  };
}
