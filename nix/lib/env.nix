{ lib, config, ... }: with lib; rec {
  envOrNull = envOr null;
  envOr = fallback: key: let
    value = builtins.getEnv key;
  in if value == "" then fallback else value;
  envIsSet = key: if config.environment.impure
    then envOrNull key != null
    else false;
  envMappings = {
    global = {
      platform =
        if envOrNull "GITHUB_ACTIONS" == "true" then "gh-actions"
        else "none";
      git-commit = null; # TODO: fall back to IFD pulling this info from .git?
      git-ref = null; # TODO: ditto, just read .git/HEAD?
      git-tag = let
        tag = builtins.match "refs/tags/(.*)" (toString config.lib.ci.env.git-ref);
      in if tag != null then head tag else null;
      git-branch = let
        branch = builtins.match "refs/heads/(.*)" (toString config.lib.ci.env.git-ref);
      in if branch != null then head branch else null;
      slug = null; # TODO: fall back to getting this from the git remote url..?
      tmpdir = null;
      build-dir = null; # TODO: fall back to config root?
      work-dir = null;
      pr-head = null;
      pr-base = null;
    };
    gh-actions = {
      git-commit = envOrNull "GITHUB_SHA";
      git-ref = envOrNull "GITHUB_REF";
      slug = envOrNull "GITHUB_REPOSITORY";
      gh-slug = envOrNull "GITHUB_REPOSITORY";
      gh-actor = envOrNull "GITHUB_ACTOR";
      tmpdir = envOrNull "RUNNER_TEMP";
      build-dir = envOrNull "GITHUB_WORKSPACE"; # git repo checkout goes here
      work-dir = envOrNull "RUNNER_WORKSPACE"; # this is um, a workspace? it's actually the parent of the build-dir...
      gh-event-name = envOrNull "GITHUB_EVENT_NAME"; # "push", "pull_request", etc
      gh-event = importJSON (envOrNull "GITHUB_EVENT_PATH");
      gh-workflow = envOrNull "GITHUB_WORKFLOW"; # workflow name/id
      gh-action = envOrNull "GITHUB_ACTION"; # an id of sorts?
      pr-head = envOrNull "GITHUB_HEAD_REF";
      pr-base = envOrNull "GITHUB_BASE_REF";
      # TODO: option for making sure nix does builds in a tmpfs? disks are slow!
    };
  };
  envKey = k: "CI_${replaceStrings [ "-" ] [ "_" ] (toUpper k)}";
  env = let
    filtered = filterAttrs (_: v: v != null);
    globalEnv = mapAttrs (k: v: envOrNull (envKey k)) envMappings.global;
    global = envMappings.global;
  in global // filtered envMappings.${global.platform} or { } // filtered globalEnv // {
    get = envOrNull;
    getOr = envOr;
    isSet = envIsSet;
  };
}
