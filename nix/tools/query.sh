#!@runtimeShell@
set -euo pipefail

if [[ -n "@nix@" ]]; then
	export PATH="@nix@/bin:$PATH"
fi

nix-env -qas --show-trace --drv-path --out-path "$@"
