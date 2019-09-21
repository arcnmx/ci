#!@runtimeShell@
set -euo pipefail

OPT_IGNORE_LOCAL=

if [[ $# -gt 0 ]]; then
	if [[ $1 = -i ]]; then
		# only check substituters, ignore whether the package is installed or not
		OPT_IGNORE_LOCAL=1
	fi
fi

validStorePath() {
	if [[ -n $OPT_IGNORE_LOCAL ]]; then
		false
	else
		#nix path-info "$2" > /dev/null 2>&1
		nix-store -u -q --hash "$1" > /dev/null 2>&1
	fi
}

while read -r line; do
	LINE=($line)
	if [[ ${LINE[1]} = /* ]]; then
		# fixup weird issues when name is missing from the output?
		LINE=(${LINE[0]} ${LINE[2]#*-} ${LINE[1]} ${LINE[2]})
	fi
	# STATUS NAME DRV_PATH OUTPATHS
	# STATUS FORMAT: IPS (Installed drvPresent Substitutable, with - in place if false)
	if [[ ${LINE[0]} = ??- ]] && ! validStorePath ${LINE[2]} ${LINE[3]}; then
		# filter for derivations that are neither installed nor available from a binary substitute
		echo ${LINE[2]}
	fi
done | @coreutils@/bin/sort -u
