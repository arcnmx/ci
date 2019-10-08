#!@runtimeShell@
set -eu

CI_CACHE_LIST=($(cat))

source $CI_BUILD_ATTRS

if [[ ${#CI_CACHE_LIST[@]} -gt 0 && -n ${CACHIX_SIGNING_KEY-} && -n ${CACHIX_CACHE-} ]]; then
  echo ${CI_CACHE_LIST[*]} | @cachix@/bin/cachix push "$CACHIX_CACHE" || true
fi
