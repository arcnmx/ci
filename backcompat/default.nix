let
  inherit (builtins) readFile fromJSON fetchTarball;
  lockfile = fromJSON (readFile ./flake.lock);
  input = lockfile.nodes.ci.locked;
  ci = fetchTarball {
    url = "https://github.com/${input.owner}/${input.repo}/archive/${input.rev}.tar.gz";
    sha256 = input.narHash;
  };
in ci
