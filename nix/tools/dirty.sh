#!@runtimeShell@
set -euo pipefail

@jq@/bin/jq -re 'select(.substitutable == false and .installed == false) | .drvPath' | @coreutils@/bin/sort -u
