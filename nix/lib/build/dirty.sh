#!@runtimeShell@
set -eu

source $CI_BUILD_ATTRS

@sourceOps@

# hack around issues that arise from evaluating this builder multiple times
case ${CI_PLATFORM-} in
  gh-actions)
    if [[ -v GITHUB_ENV ]]; then
      echo "CI_BUILD_ATTRS=$CI_BUILD_ATTRS" >> $GITHUB_ENV
    else
      echo "::set-env name=CI_BUILD_ATTRS::$CI_BUILD_ATTRS" >&2
    fi
    ;;
  azure-pipelines)
    echo "##vso[task.setvariable variable=CI_BUILD_ATTRS]$CI_BUILD_ATTRS" >&2
    ;;
esac

opFilterNoisy $drvImports
