#!@runtimeShell@
set -euo pipefail

@jq@/bin/jq -r 'select(.substitutable == false and .installed == false) | .drvPath' | @coreutils@/bin/sort -u
