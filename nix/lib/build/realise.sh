#!@runtimeShell@
set -eu

CI_DRV_DIRTY=($(cat))

source $CI_BUILD_ATTRS

@sourceOps@

eval "$preBuild"

if [[ -n $drvExecutor ]]; then
  # TODO: just make this part of preBuild?
  export EX_PIDFILE=$(mktemp)
  $drvExecutor
  trap 'kill -QUIT $(cat $EX_PIDFILE)' EXIT
fi

# TODO: use --add-root with --indirect in a ci cache dir?
(( ${#CI_DRV_DIRTY[@]} == 0 )) || opRealise "${CI_DRV_DIRTY[@]}" --show-trace --keep-going "$@"
