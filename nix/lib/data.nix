{ ... }@args: {
  ciRepoInfo = rec {
    latestVersion = true;
    version = "0.7";
    releaseName = "v${version}";
    releaseRef = "refs/tags/${releaseName}";
    devBranch = "main";
  };
}
