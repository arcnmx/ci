{ ... }@args: {
  ciRepoInfo = rec {
    latestVersion = false;
    version = "0.6";
    releaseName = "v${version}";
    releaseRef = "refs/tags/${releaseName}";
    devBranch = "main";
  };
}
