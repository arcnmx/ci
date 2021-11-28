{ writeShellScriptBin, curl }: let
  url = "";
  # NOTE: consider using a flake source for this and load it via `fromJSON`?
in writeShellScriptBin "cachix-key" ''
  CACHE_NAME=$1

  ${curl}/bin/curl "https://app.cachix.org/api/v1/cache/$CACHE_NAME" |
    ${jq}/bin/jq -r .publicSigningKeys
''
