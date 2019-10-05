{ lib, config, ... }: with lib; rec {
  hostPath = let
    paths' = splitString ":" (builtins.getEnv "PATH");
    paths = builtins.filter (p: p != "") (filter builtins.pathExists paths');
  in map (path: { inherit path; prefix = ""; }) paths;
  hostDep = name: bins: let
    binTry = map (bin: builtins.tryEval (builtins.findFile hostPath bin)) (toList bins);
    success = all (bin: bin.success) binTry;
    binPaths = map (bin: bin.value) binTry;
    drv = config.bootstrap.pkgs.linkFarm "${name}-host-impure" (map (bin: {
      name = "bin/${builtins.baseNameOf bin}";
      path = toString bin;
    }) binPaths);
  in if success then drv else null;
}
