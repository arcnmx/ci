{ pkgs ? import <nixpkgs> { }, ci ? throw "ci" }: {
  ciConfig = {
    basePackages = rec {
      jq = ci.hostDep "jq" [ "jq" ];
      jqhello = pkgs.writeShellScriptBin "jqhello" ''
        ${jq}/bin/jq -er .hello -
      '';
    };
  };
}
