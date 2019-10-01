#!@runtimeShell@
set -euo pipefail

OPT_IGNORE_LOCAL=
OPT_VERBOSE=

if [[ $# -gt 0 ]]; then
	if [[ $1 = -i ]]; then
		shift
		# only check substituters, ignore whether the package is installed or not
		OPT_IGNORE_LOCAL=1
	fi
	if [[ $1 = -v ]]; then
		shift
		# give more feedback via stderr
		OPT_VERBOSE=1
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

{
	CLEAN=()
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
			if [[ -n $OPT_VERBOSE ]]; then
				echo "${LINE[1]} :: ${LINE[3]}" >&2
			fi
		elif [[ -n $OPT_VERBOSE ]]; then
			CLEAN+=("${LINE[1]} :: ${LINE[0]} ${LINE[3]}")
		fi
	done

	for clean in ${CLEAN[@]+"${CLEAN[@]}"}; do
		echo "[CLEAN] $clean" >&2
	done
} | @coreutils@/bin/sort -u
