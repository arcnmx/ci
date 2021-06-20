#!/usr/bin/env bash

set -euo pipefail

if type -P nix > /dev/null; then
  return
fi

NIX_VERSION=${NIX_VERSION-latest}
if [[ $NIX_VERSION != latest && $NIX_VERSION != nix-* ]]; then
  NIX_VERSION=nix-$NIX_VERSION
fi

case "$(uname -s).$(uname -m)" in
  Linux.x86_64) NIX_SYSTEM=x86_64-linux;;
  Linux.i?86) NIX_SYSTEM=i686-linux;;
  Linux.aarch64) NIX_SYSTEM=aarch64-linux;;
  Darwin.x86_64) NIX_SYSTEM=x86_64-darwin;;
esac

if [[ $NIX_VERSION = latest ]]; then
  NIX_VERSION=$(curl -fsSL https://nixos.org/nix/install | grep -o 'nix-[0-9.]*' | tail -n1)
fi
NIX_URL=https://nixos.org/releases/nix/$NIX_VERSION
NIX_VERSION=${NIX_VERSION#nix-}

NIX_BASE=nix-$NIX_VERSION-$NIX_SYSTEM
NIX_URL=$NIX_URL/$NIX_BASE.tar

echo "Downloading $NIX_BASE..." >&2

makedir() {
  sudo mkdir -pm 0755 $1 && sudo chown $(id -u) $1
}

NIX_STORE_DIR=/nix
makedir /etc/nix
if ! makedir $NIX_STORE_DIR; then
  if [[ $NIX_SYSTEM = *-darwin ]]; then
    # macos catalina mounts root readonly
    if sudo mount -uw /; then
      # if SIP is disabled this will still work...
      makedir $NIX_STORE_DIR
    else
      # otherwise best we can do is tell macos to make us a symlink
      # see also: https://github.com/NixOS/nix/pull/3212
      NIX_STORE_CANON=/opt/nix
      makedir $NIX_STORE_CANON
      echo -e "nix\\t$NIX_STORE_CANON" | sudo tee -a /etc/synthetic.conf > /dev/null
      if ! /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -B; then
        echo "failed to create synthetic link" >&2
        exit 1
      fi
      export NIX_IGNORE_SYMLINK_STORE=1
    fi
  else
    exit 1
  fi
fi
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

# nix 2.4 may disable the nix command?
case $NIX_VERSION in
  1.*|2.[0123]*)
    ;;
  *)
    echo 'experimental-features = nix-command' >> /etc/nix/nix.conf
    ;;
esac

if [[ -n ${CI_NIX_PATH_NIXPKGS-} ]]; then
  export NIX_PATH="${NIX_PATH-}${NIX_PATH+:}nixpkgs=$($NIX_PATH_DIR/nix eval --raw -f "$CI_ROOT/nix/lib/cipkgs.nix" nixpkgsUrl.url)"
fi

# set up a default config
cat $($NIX_PATH_DIR/nix eval --raw --arg config ${CI_CONFIG-$CI_ROOT/tests/empty.nix} ci.config.nix.configFile) >> /etc/nix/nix.conf

export_env() {
  case "${CI_PLATFORM-}" in
    gh-actions)
      if [[ -n "${GITHUB_ENV-}" ]]; then
        echo "$1=$2" >> $GITHUB_ENV
      else
        echo "::set-env name=$1::$2" >&2
      fi
      ;;
    azure-pipelines)
      echo "##vso[task.setvariable variable=$1]$2" >&2
      ;;
  esac
}

export_env NIX_VERSION "$NIX_VERSION"
export_env NIX_SSL_CERT_FILE "$NIX_SSL_CERT_FILE"
export_env CI_CONFIG_ROOT "$CI_CONFIG_ROOT"
if [[ -n ${NIX_PATH-} ]]; then
  export_env NIX_PATH "$NIX_PATH"
fi
if [[ -n ${NIX_IGNORE_SYMLINK_STORE-} ]]; then
  export_env NIX_IGNORE_SYMLINK_STORE "$NIX_IGNORE_SYMLINK_STORE"
fi

case "${CI_PLATFORM-}" in
  gh-actions)
    echo "::set-output name=version::$NIX_VERSION" >&2
    echo "::set-output name=nix-path::${NIX_PATH-}" >&2
    if [[ -n "${GITHUB_PATH-}" ]]; then
      echo "$NIX_PATH_DIR" >> $GITHUB_PATH
    else
      echo "::add-path::$NIX_PATH_DIR" >&2
    fi
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
