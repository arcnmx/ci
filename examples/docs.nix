{ config, pkgs, lib, ... }: with lib; {
  gh-actions.env = {
    GIT_DEPLOY_KEY = "\${{ secrets.deploy_key }}";
  };
  tasks = {
    build.inputs = [ config.doc.manual ];
    deploy = {
      preBuild = optionalString (builtins.getEnv "GIT_DEPLOY_KEY" != "") ''
        echo "$GIT_DEPLOY_KEY" > /tmp/${placeholder "GIT_DEPLOY_KEY"}
      '';
      inputs = pkgs.ci.command {
        name = "deploy";
        impure = true;
        skip =
          if builtins.getEnv "GITHUB_EVENT_NAME" != "push" then builtins.getEnv "GITHUB_EVENT_NAME"
          # else if builtins.getEnv "GITHUB_REF" != "master" then "branch"
          else if builtins.getEnv "GIT_DEPLOY_KEY" == "" then "missing key"
          else false;
        environment = [ "GITHUB_REPOSITORY" "GITHUB_SHA" ];
        #nativeBuildInputs = with pkgs; [ openssh gitMinimal ];
        command = ''
          DOCDIR=$(mktemp -d)
          cd $DOCDIR

          cp -a ${config.doc.manual}/share/doc/ci/* ./
          git init

          git remote add origin "https://github.com/$GITHUB_REPOSITORY"
          git remote set-url --push origin git@github.com:$GITHUB_REPOSITORY
          git fetch origin gh-pages && git reset origin/gh-pages || true

          git add -A .
          git config user.name ghost
          git config user.email ghost@konpa.ku
          git commit -m "$GITHUB_SHA"

          install -Dm0600 /tmp/${placeholder "GIT_DEPLOY_KEY"} deployKey
          GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i deployKey" git push -q origin HEAD:gh-pages
        '';
      };
    };
  };
}
