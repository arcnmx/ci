#!@runtimeShell@
set -euo pipefail

while read -r line; do
	LINE=($line)
	# STATUS NAME DRV_PATH OUTPATHS
	# STATUS FORMAT: IPS (installed drvPresent Substitutable, with - in place if false)
	if [[ ${LINE[0]} = -?- ]]; then
		# filter for derivations that are neither installed nor available from a binary substitute
		echo ${LINE[2]}
	fi
done | @coreutils@/bin/sort -u
