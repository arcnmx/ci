{ config, pkgs, ... }: {
  gh-actions.env = {
    GITHUB_EVENT_NAME = "\${{ github.event_name }}";
    GITHUB_REF = "\${{ github.ref }}";
    GITHUB_SHA = "\${{ github.sha }}";
    GITHUB_REPOSITORY = "\${{ github.repository }}";
    GIT_DEPLOY_KEY = "\${{ secrets.deploy_key }}";
  };
  tasks = {
    build.inputs = [ config.doc.manual ];
    deploy.inputs = pkgs.ci.command {
      name = "deploy";
      impure = true;
      skip =
        if builtins.getEnv "GITHUB_EVENT_NAME" != "push" then builtins.getEnv "GITHUB_EVENT_NAME"
        # else if builtins.getEnv "GITHUB_REF" != "master" then "branch"
        else if builtins.getEnv "GIT_DEPLOY_KEY" == "" then "missing key"
        else false;
      command = ''
        DOCDIR=$(mktemp -d)
        cp -a ${config.doc.manual}/share/doc/ci/* $DOCDIR/
        cd $DOCDIR
        git init

        git remote add origin "https://github.com/$GITHUB_REPOSITORY"
        git remote set-url --push origin git@github.com:$GITHUB_REPOSITORY
        git fetch origin gh-pages && git reset origin/gh-pages || true

        git add -A .
        git config user.name ghost
        git config user.email ghost@konpa.ku
        git commit -m "$GITHUB_SHA"

        echo "$GIT_DEPLOY_KEY" > deployKey
        chmod og-rw deployKey
        GIT_SSH_COMMAND="ssh -i deployKey" git push -q origin HEAD:gh-pages
      '';
    };
  };
}
