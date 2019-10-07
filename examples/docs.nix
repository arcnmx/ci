{ config, pkgs, lib, env, ... }: with lib; {
  gh-actions.env = {
    GIT_DEPLOY_KEY = "\${{ secrets.deploy_key }}";
  };
  tasks = {
    build.inputs = [ config.doc.manual ];
    deploy = let
      deployKeyPath = "${env.tmpdir}/${placeholder "GIT_DEPLOY_KEY"}";
    in {
      preBuild = optionalString (env.get "GIT_DEPLOY_KEY" != null) ''
        echo "$GIT_DEPLOY_KEY" > ${deployKeyPath}
      '';
      inputs = pkgs.ci.command {
        name = "deploy";
        impure = true;
        skip =
          if env.platform != "gh-actions" || env.gh-event-name != "push" then env.gh-event-name
          # else if env.git-branch != "master" then "branch"
          else if env.get "GIT_DEPLOY_KEY" == null then "missing key"
          else false;
        gitCommit = env.git-commit;
        gitRemote = "https://github.com/${env.gh-slug or ""}";
        gitRemotePush = "git@github.com:${env.gh-slug or ""}";
        docsBranch = "gh-pages";
        inherit deployKeyPath;
        #nativeBuildInputs = with pkgs; [ openssh gitMinimal ];
        command = ''
          DOCDIR=$(mktemp -d)
          cd $DOCDIR

          cp -a ${config.doc.manual}/share/doc/ci/* ./
          git init

          git remote add origin $gitRemote
          git remote set-url --push origin $gitRemotePush
          git fetch origin $docsBranch && git reset origin/$docsBranch || true

          git add -A .
          git config user.name ghost
          git config user.email ghost@konpa.ku
          git commit -m "$gitCommit"

          install -Dm0600 $deployKeyPath deployKey
          GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -i deployKey" git push -q origin HEAD:$docsBranch
        '';
      };
    };
  };
}
