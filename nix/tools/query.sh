#!@runtimeShell@
set -euo pipefail

ENV_FILTER='[.items.item] | flatten | .[] | {
	name: .["@name"],
	drvPath: .["@drvPath"],
	attrPath: .["@attrPath"],
	substitutable: (.["@substitutable"] == "1"),
	installed: (.["@installed"] == "1"),
	valid: (.["@valid"] == "1")
}'

@nix@/bin/nix-env -qas --show-trace --drv-path --out-path --xml "$@" | @yq@/bin/xq -ce "$ENV_FILTER"
