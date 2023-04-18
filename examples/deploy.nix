{ config, pkgs, lib, env, ... }: with lib; {
  ci.gh-actions = {
    checkoutVersion = "v3";
    checkoutOptions = {
      fetch-depth = 0;
    };
  };
  tasks = {
    smoke.inputs = [
      (pkgs.ci.command {
        name = "pure";
        command = ''
         echo hello from inside the $NIX_BUILD_TOP sandbox
        '';
      })
    ];
    deploy = let
      inherit (import ../nix/lib/data.nix { }) ciRepoInfo;
      deploy-tag = pkgs.ci.command {
        name = "deploy-tag";
        displayName = "deploy tag";
        impure = true;
        skip =
          if env.platform != "gh-actions" || env.gh-event-name != "push" then env.gh-event-name or env.platform
          else if env.git-branch != ciRepoInfo.devBranch then "branch"
          else false;
        gitCommit = env.git-commit;
        gitTag = removePrefix "refs/tags/" ciRepoInfo.releaseRef;
        releaseTag = optionalString (ciRepoInfo.releaseRef != "refs/tags/${ciRepoInfo.releaseName}") ciRepoInfo.releaseName;
        smokeTest = config.tasks.smoke.drv;
        command = ''
          git tag -f $gitTag $gitCommit
          if [[ -n $releaseTag ]]; then
            git tag -f $releaseTag $gitTag
          fi
          git push -fq origin $releaseTag $gitTag
        '';
      };
    in {
      inputs =
        optional (hasPrefix "refs/tags/" ciRepoInfo.releaseRef) deploy-tag
        ++ optional (hasPrefix "refs/heads/" ciRepoInfo.releaseRef) (throw "TODO: release branch unsupported");
    };
  };
}
