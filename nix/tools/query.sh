#!@runtimeShell@
set -euo pipefail

@nix@/bin/nix-env -qas --show-trace --drv-path --out-path "$@"
