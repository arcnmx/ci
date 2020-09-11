#!@runtimeShell@
set -eu

CI_CACHE_LIST=($(cat))

source $CI_BUILD_ATTRS

if [[ ${#CI_CACHE_LIST[@]} -gt 0 && -n ${CACHIX_SIGNING_KEY-} && -n ${CACHIX_CACHE-} ]]; then
  FILTERED=()
  for path in "${CI_CACHE_LIST[@]}"; do
    if [[ -e $path ]]; then
      FILTERED+=("$path")
    fi
  done
  echo ${FILTERED[*]} | @cachix@/bin/cachix push "$CACHIX_CACHE" || true
fi
