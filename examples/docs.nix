{ config, pkgs, lib, env, ... }: with lib; {
  ci.gh-actions = {
    checkoutVersion = "v3";
    checkoutOptions = {
      fetch-depth = 0;
    };
  };
  tasks = {
    build.inputs = [ config.doc.manual ];
    deploy = let
      inherit (import ../nix/lib/data.nix { }) ciRepoInfo;
      deploy-docs = pkgs.ci.command {
        name = "deploy-docs";
        displayName = "deploy docs";
        impure = true;
        skip =
          if env.platform != "gh-actions" || env.gh-event-name != "push" then env.gh-event-name or env.platform
          else if env.git-branch != ciRepoInfo.devBranch then "branch"
          else if !ciRepoInfo.latestVersion then "outdated"
          else false;
        gitCommit = env.git-commit;
        docsBranch = "gh-pages";
        command = ''
          DOCDIR=$(mktemp -d)
          git fetch origin $docsBranch
          git worktree add $DOCDIR $docsBranch
          cd $DOCDIR

          cp -a ${config.doc.manual}/share/doc/ci/* ./

          git add -A .
          git config user.name ghost
          git config user.email ghost@konpa.ku
          git commit -m "manual of $gitCommit"

          git push -q origin HEAD:$docsBranch
        '';
      };
    in {
      inputs = [ deploy-docs ];
    };
  };
}
