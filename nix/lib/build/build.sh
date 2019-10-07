#!@runtimeShell@
set -eu

CI_DRV_DIRTY=$(ci-build-dirty)

CI_EXIT_CODE=0
if [[ -z ${CI_DRY_RUN-} ]]; then
  echo $CI_DRV_DIRTY | ci-build-realise || CI_EXIT_CODE=0
fi
export CI_EXIT_CODE

EXIT_CODE=0
CI_CACHE_LIST=$(echo $CI_DRV_DIRTY | ci-build-summarise) || EXIT_CODE=$?

echo $CI_CACHE_LIST | ci-build-cache

exit $EXIT_CODE
