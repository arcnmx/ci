#!@runtimeShell@
set -eu

CI_DRV_DIRTY=($(cat))

source $CI_BUILD_ATTRS

@sourceOps@

drv_dirty() {
  drv_skipped $1 || [[ " ${CI_DRV_DIRTY[@]} " =~ " $1 " ]]
}

drv_valid() {
  if drv_skipped $1; then
    return 1
  else
    @nix@/bin/nix-store -u -q --hash $1 > /dev/null 2>&1
  fi
}

drv_warn() {
  [[ -n ${drvWarn[$1]-} ]]
}

drv_skipped() {
  [[ -n ${drvSkipped[$1]-} ]]
}

drv_report() {
  # drv, status = ok|fail|cache, nested=1
  local REPORT_MSG REPORT_ICON REPORT_COLOUR

  if [[ $2 = ok ]] && ! drv_dirty $1; then
    REPORT_MSG=cache
  elif [[ $2 = fail && -n ${CI_DRY_RUN-} ]]; then
    REPORT_MSG=dry
  else
    REPORT_MSG=$2
  fi

  case $REPORT_MSG in
    fail)
      if drv_warn $1; then
        REPORT_COLOUR=@yellow@
        REPORT_MSG="failed (allowed, ignored)"
        #REPORT_ICON="⚠️"
        REPORT_ICON="!"
        if [[ ${CI_PLATFORM-} = gh-actions ]]; then
          echo "::warning::${drvName[$1]} failed to build" >&2
        fi
      else
        REPORT_COLOUR=@red@
        REPORT_MSG=failed
        REPORT_ICON=❌
        if [[ -z ${3-} ]]; then
          EXIT_CODE=1
        fi
        if [[ ${CI_PLATFORM-} = gh-actions ]]; then
          echo "::error::${drvName[$1]} failed to build" >&2
        fi
      fi
      ;;
    ok)
      REPORT_COLOUR=@blue@
      REPORT_MSG=ok
      REPORT_ICON="✔️"
      CI_CACHE_LIST+=(${drvCache[$1]-})
      ;;
    cache)
      REPORT_COLOUR=@magenta@
      REPORT_MSG="ok (cached)"
      REPORT_ICON="✔️"
      ;;
    skip|dry)
      REPORT_COLOUR=@yellow@
      REPORT_ICON="•"
      if [[ $REPORT_MSG = dry ]]; then
        REPORT_MSG="skipped (dry run)"
      elif [[ -z ${drvSkipped[$1]-} || ${drvSkipped[$1]} = 1 ]]; then
        REPORT_MSG="skipped"
      else
        REPORT_MSG="skipped (${drvSkipped[$1]})"
      fi
      ;;
  esac
  echo "$REPORT_COLOUR${3+"  "}$REPORT_ICON ${drvName[$1]} $REPORT_MSG" >&2
}

# TODO: verbose option for opFilter vs opFilterNoisy?
CI_CACHE_LIST=()
EXIT_CODE=0

if (( ${#CI_DRV_DIRTY[@]} > 0 && $CI_EXIT_CODE != 0 )) || [[ -n ${CI_DRY_RUN-} ]]; then
  for drv in "${drvTasks[@]}"; do
    if drv_skipped $drv; then
      drv_report $drv skip
      for input in ${drvInputs[$drv]}; do
        drv_report $input skip 1
      done
    elif ! drv_dirty $drv || drv_valid $drv; then
      # TODO: maybe use path-info -Sh and record the size to show with the results?
      drv_report $drv ok
      for input in ${drvInputs[$drv]}; do
        if drv_skipped $input; then
          drv_report $input skip 1
        else
          drv_report $input ok 1
        fi
      done
    else
      drv_report $drv fail
      for input in ${drvInputs[$drv]}; do
        if drv_skipped $input; then
          drv_report $input skip 1
        elif ! drv_dirty $input || drv_valid $input; then
          drv_report $input ok 1
        else
          drv_report $input fail 1
          if [[ -z ${CI_DRY_RUN-} ]]; then
            nix-store -r $input --dry-run 2>&1 | (@gnugrep@/bin/grep -vFe 'these derivations will be built' -e "$input" | @gnused@/bin/sed -n '/^these paths will be fetched/q;p' >&2 || true)
            # TODO: parse the above list and show more info via nix-store query or something?
          fi
        fi
      done
      # TODO: print out part of failure log?
    fi
  done
else
  for drv in "${drvTasks[@]}"; do
    if drv_skipped $drv; then
      drv_report $drv skip
    else
      drv_report $drv ok
      for input in ${drvInputs[$drv]}; do
        if drv_skipped $input; then
          drv_report $input skip 1
        else
          drv_report $input ok 1
        fi
      done
    fi
  done
fi

printf %s @clear@ >&2

# TODO: consider listing tasks that aren't cached (local) but don't get rebuilt because dirty filter includes local?

echo ${CI_CACHE_LIST[*]}

exit $EXIT_CODE
