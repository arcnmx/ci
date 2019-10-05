#!/usr/bin/env bash
set -xeu
unset NIX_PATH

if ! command -v nix > /dev/null; then
	# install nix!
	NIX_VERSION=${NIX_VERSION-latest}
	export _NIX_INSTALLER_TEST=1
	sh <(curl https://nixos.org/releases/nix/$NIX_VERSION/install) --no-daemon
fi

# set up a known path where our environment goes
export CI_ENV=$PWD/result
export NIX_PATH="ci=${CI_ROOT-$PWD/../}"
export CI_CONFIG=./ci.nix

# build the base/bootstrap environment and replace CI_ENV with final environment
# this step installs dependencies from channels, can use additional caches, etc.
bash -lc "nix run -L ci.run.bootstrap"

# environment ready to go at this point
export BASH_ENV=$CI_ENV/ci/source
bash -c "crex --help | lolcat"

set +x
# or from a single script
source $BASH_ENV
crex --help | lolcat
