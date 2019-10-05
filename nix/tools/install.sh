#!/usr/bin/env bash

set -euo pipefail

if type -P nix > /dev/null; then
  return
fi

NIX_VERSION=${NIX_VERSION-latest}
if [[ $NIX_VERSION != latest && $NIX_VERSION != nix-* ]]; then
  NIX_VERSION=nix-$NIX_VERSION
fi

NIX_URL=https://nixos.org/releases/nix/$NIX_VERSION

case "$(uname -s).$(uname -m)" in
  Linux.x86_64) NIX_SYSTEM=x86_64-linux;;
  Linux.i?86) NIX_SYSTEM=i686-linux;;
  Linux.aarch64) NIX_SYSTEM=aarch64-linux;;
  Darwin.x86_64) NIX_SYSTEM=x86_64-darwin;;
esac

if [[ $NIX_VERSION = latest ]]; then
  NIX_VERSION=$(curl -fsSL $NIX_URL/install | grep -o 'nix-[0-9.]*' | tail -n1)
fi
NIX_VERSION=${NIX_VERSION#nix-}

NIX_BASE=nix-$NIX_VERSION-$NIX_SYSTEM
NIX_URL=$NIX_URL/$NIX_BASE.tar

NIX_STORE_DIR=/nix
sudo mkdir -pm 0755 $NIX_STORE_DIR /etc/nix
sudo chown $(id -u) $NIX_STORE_DIR /etc/nix
if curl -fsSLI $NIX_URL.xz > /dev/null; then
  tar -C $NIX_STORE_DIR --strip-components=1 -xJf <(curl -fSL $NIX_URL.xz)
else
  tar -C $NIX_STORE_DIR --strip-components=1 -xjf <(curl -fSL $NIX_URL.bz2)
fi
rm $NIX_STORE_DIR/*.sh

NIX_STORE_NIX=$(cd $NIX_STORE_DIR/store && echo *-nix-2*)
NIX_STORE_CACERT=$(cd $NIX_STORE_DIR/store && echo *-nss-cacert-*)
NIX_PROFILE="$NIX_STORE_DIR/store/$NIX_STORE_NIX/etc/profile.d/nix.sh"

export NIX_SSL_CERT_FILE="$NIX_STORE_DIR/store/$NIX_STORE_CACERT/etc/ssl/certs/ca-bundle.crt"
export NIX_PATH_DIR="$NIX_STORE_DIR/store/$NIX_STORE_NIX/bin"

$NIX_PATH_DIR/nix-store --init
$NIX_PATH_DIR/nix-store --load-db < $NIX_STORE_DIR/.reginfo
rm $NIX_STORE_DIR/.reginfo
export CI_CONFIG_ROOT="${CI_CONFIG_ROOT-$PWD}"

if [[ -n ${CI_NIX_PATH_NIXPKGS-} ]]; then
  export NIX_PATH="${NIX_PATH-}${NIX_PATH+:}nixpkgs=$($NIX_PATH_DIR/nix eval --raw -f "$CI_ROOT/nix/lib/cipkgs.nix" nixpkgsUrl.url)"
fi

# set up a default config
cat $($NIX_PATH_DIR/nix eval --raw --arg config ${CI_CONFIG-$CI_ROOT/tests/empty.nix} ci.config.nix.configFile) >> /etc/nix/nix.conf

export_env() {
  case "${CI_PLATFORM-}" in
    gh-actions)
      echo "::set-env name=$1::$2"
      ;;
    azure-pipelines)
      echo "##vso[task.setvariable variable=$1]$2"
      ;;
  esac
}

export_env NIX_VERSION "$NIX_VERSION"
export_env NIX_SSL_CERT_FILE "$NIX_SSL_CERT_FILE"
export_env CI_CONFIG_ROOT "$CI_CONFIG_ROOT"
if [[ -n ${NIX_PATH-} ]]; then
  export_env NIX_PATH "$NIX_PATH"
fi

case "${CI_PLATFORM-}" in
  gh-actions)
    echo "::set-output name=version::$NIX_VERSION"
    echo "::set-output name=nix-path::${NIX_PATH-}"
    echo "::add-path::$NIX_PATH_DIR"
    sudo chown 0:0 / || true
    ;;
  azure-pipelines)
    sudo chown 0:0 / || true
    cat >> ~/.bash_profile <<EOF

export PATH="$NIX_PATH_DIR:\$PATH"
#source "$NIX_PROFILE"
EOF
    ;;
esac
