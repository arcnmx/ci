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
CI_CONFIG=ci.nix

# build the base/bootstrap environment
# just core dependencies, CI helper scripts, cachix, pinned to a stable nixpkgs
bash -lc "nix -L --show-trace run -f ../ env.bootstrapEnv --argstr config $CI_CONFIG -c ci-setup"

# setup replaces CI_ENV with final environment
# this step installs dependencies from channels, can use additional caches, etc.
export BASH_ENV=$CI_ENV/ci/source

# environment ready to go at this point
bash -c "crex --help | lolcat"

set +x
# or from a single script
source $BASH_ENV
crex --help | lolcat
