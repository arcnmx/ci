#!/usr/bin/env bash

set -euo pipefail

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

set_output() {
  case "${CI_PLATFORM-}" in
    gh-actions)
      if [[ -n "${GITHUB_OUTPUT-}" ]]; then
        echo "$1=$2" >> $GITHUB_OUTPUT
      else
        echo "::set-output name=$1::$2" >&2
      fi
      ;;
  esac
}

add_path() {
  case "${CI_PLATFORM-}" in
    gh-actions)
      if [[ -n "${GITHUB_PATH-}" ]]; then
        echo "$1" >> $GITHUB_PATH
      else
        echo "::add-path::$1" >&2
      fi
      ;;
    azure-pipelines)
      sudo chown 0:0 / || true
      cat >> ~/.bash_profile <<EOF
export PATH="$1:\$PATH"
EOF
      ;;
  esac
}

maketemp() {
  local MKTEMP_PREFIX=$1
  shift

  mktemp "$@" --tmpdir "${MKTEMP_PREFIX}.XXXXXXXXXX" || mktemp "$@"
}

nix_eval() {
  local NIX_EVAL_FILE=$1 NIX_EVAL_ATTR=$2 NIX_EVAL_OUT
  shift 2

  NIX_EVAL_OUT="$($NIX_PATH_DIR/nix-instantiate --eval --json "$NIX_EVAL_FILE" -A "$NIX_EVAL_ATTR" "$@")"
  NIX_EVAL_OUT="${NIX_EVAL_OUT#\"}"
  NIX_EVAL_OUT="${NIX_EVAL_OUT%\"}"
  printf "$NIX_EVAL_OUT"
}

setup_nix_path() {
  export CI_CONFIG_ROOT="${CI_CONFIG_ROOT-$PWD}"
  export_env CI_CONFIG_ROOT "$CI_CONFIG_ROOT"

  export_env NIX_BIN_DIR "$NIX_PATH_DIR"

  NIX_USER_CONF=$(nix_eval '<ci>' config.nix.settingsText --argstr config "${CI_CONFIG-$CI_ROOT/tests/empty.nix}")
  NIX_USER_CONF_FILE=$(maketemp ci.nix.user.conf)
  printf "%s" "$NIX_USER_CONF" > "$NIX_USER_CONF_FILE"
  export NIX_USER_CONF_FILES="${NIX_USER_CONF_FILES-${XDG_CONFIG_HOME-$HOME/.config}/nix/nix.conf}:$NIX_USER_CONF_FILE"
  export_env NIX_USER_CONF_FILES "$NIX_USER_CONF_FILES"

  if [[ -n ${CI_NIX_PATH_NIXPKGS-} ]]; then
    export NIX_PATH="${NIX_PATH-}${NIX_PATH+:}nixpkgs=$(nix_eval "$CI_ROOT/nix/lib/cipkgs.nix" nixpkgsUrl.url)"
  fi
  if [[ -n ${NIX_PATH-} ]]; then
    export_env NIX_PATH "$NIX_PATH"
  fi
  set_output nix-path "${NIX_PATH-}"
}

if type -P nix > /dev/null; then
  export NIX_PATH_DIR=$(dirname "$(readlink -f "$(type -P nix)")")

  NIX_VERSION=$(nix --version)
  if [[ $NIX_VERSION = "nix "* ]]; then
    NIX_VERSION=${NIX_VERSION##* }
    export_env NIX_VERSION "$NIX_VERSION"
    set_output version "$NIX_VERSION"
  fi

  setup_nix_path
  exit
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
  Darwin.arm64|Darwin.aarch64) NIX_SYSTEM=aarch64-darwin;;
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
  if ! mkdir -pm 0755 "$1" 2>/dev/null; then
    sudo mkdir -pm 0755 "$1" && sudo chown $(id -u) "$1"
  fi
}

installer_fallback() {
  NIX_INSTALLER=$1
  NIX_STORE_DIR=$HOME/nix-install
  mkdir $NIX_STORE_DIR
}

NIX_INSTALLER=${NIX_INSTALLER-}
NIX_STORE_DIR=/nix
if [[ -n $NIX_INSTALLER ]]; then
  installer_fallback "$NIX_INSTALLER"
elif ! makedir $NIX_STORE_DIR; then
  if [[ $NIX_SYSTEM = *-darwin ]]; then
    # macos catalina mounts root readonly
    if sudo mount -uw /; then
      # if SIP is disabled this will still work...
      makedir $NIX_STORE_DIR
    elif /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -B >/dev/null 2>&1; then
      # otherwise best we can do is tell macos to make us a symlink
      # see also: https://github.com/NixOS/nix/pull/3212
      NIX_STORE_CANON=/opt/nix
      makedir $NIX_STORE_CANON
      echo -e "nix\\t$NIX_STORE_CANON" | sudo tee -a /etc/synthetic.conf > /dev/null
      /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -B
      export NIX_IGNORE_SYMLINK_STORE=1
    else
      installer_fallback --daemon
      export NIX_IGNORE_SYMLINK_STORE=1
    fi
  else
    installer_fallback --no-daemon
  fi
fi
makedir $NIX_STORE_DIR/var
makedir $NIX_STORE_DIR/var/nix
if curl -fsSLI $NIX_URL.xz > /dev/null; then
  tar -C $NIX_STORE_DIR --strip-components=1 -xJf <(curl -fSL $NIX_URL.xz)
else
  tar -C $NIX_STORE_DIR --strip-components=1 -xjf <(curl -fSL $NIX_URL.bz2)
fi

nixvars() {
  NIX_STORE_NIX=$(cd $NIX_STORE_DIR/store && echo *-nix-2*)
  NIX_STORE_CACERT=$(cd $NIX_STORE_DIR/store && echo *-nss-cacert-*)
  NIX_PROFILE="$NIX_STORE_DIR/store/$NIX_STORE_NIX/etc/profile.d/nix.sh"

  export NIX_PATH_DIR="$NIX_STORE_DIR/store/$NIX_STORE_NIX/bin"
  if [[ $NIX_INSTALLER = --daemon ]]; then
    set +eu
    source $NIX_STORE_DIR/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    set -eu
    if [[ ${NIX_SSL_CERT_FILE-} = $NIX_STORE_DIR/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt ]]; then
      unset NIX_SSL_CERT_FILE
    fi
  elif [[ ! -r /etc/ssl/certs/ca-certificates.crt ]]; then
    export NIX_SSL_CERT_FILE="$NIX_STORE_DIR/store/$NIX_STORE_CACERT/etc/ssl/certs/ca-bundle.crt"
  fi
}

if [[ -n $NIX_INSTALLER ]]; then
  INVOKED_FROM_INSTALL_IN=1 $NIX_STORE_DIR/install \
    --no-channel-add --no-modify-profile \
    --daemon-user-count ${NIX_USER_COUNT-8} \
    $NIX_INSTALLER
  rm -rf $NIX_STORE_DIR
  NIX_STORE_DIR=/nix
  nixvars
else
  nixvars

  $NIX_PATH_DIR/nix-store --init
  $NIX_PATH_DIR/nix-store --load-db < $NIX_STORE_DIR/.reginfo
fi
rm -f $NIX_STORE_DIR/*.sh $NIX_STORE_DIR/.reginfo

setup_nix_path

# set up a default config
if [[ -n $NIX_INSTALLER || ! -e /etc/nix/nix.conf ]] && [[ -z ${NIX_CONF_DIR-} ]]; then
  NIX_CONF=$(nix_eval '<ci>' config.nix.configText --argstr config "${CI_CONFIG-$CI_ROOT/tests/empty.nix}")

  if [[ $NIX_INSTALLER = --daemon ]]; then
    makedir /etc/nix
    NIX_CONF_DIR=/etc/nix
  else
    export NIX_CONF_DIR=$(maketemp ci.nix.conf -d)
    export_env NIX_CONF_DIR "$NIX_CONF_DIR"
  fi

  if [[ -w $NIX_CONF_DIR ]]; then
    printf "%s" "$NIX_CONF" >> "$NIX_CONF_DIR/nix.conf"
  else
    printf "%s" "$NIX_CONF" | sudo bash -c "cat >> $NIX_CONF_DIR/nix.conf"
  fi

  if [[ $NIX_INSTALLER = --daemon ]]; then
    if [[ $NIX_SYSTEM = *-darwin ]]; then
      launchctl kickstart -k system/org.nixos.nix-daemon ||
      sudo launchctl kickstart -k system/org.nixos.nix-daemon ||
      true
    elif [[ $NIX_SYSTEM = *-linux ]]; then
      systemctl restart nix-daemon.service ||
      sudo systemctl restart nix-daemon.service ||
      true
    fi
  fi
fi

export_env NIX_VERSION "$NIX_VERSION"
#export_env NIX_SSL_CERT_FILE "$NIX_SSL_CERT_FILE"
if [[ -n ${NIX_IGNORE_SYMLINK_STORE-} ]]; then
  export_env NIX_IGNORE_SYMLINK_STORE "$NIX_IGNORE_SYMLINK_STORE"
fi

set_output version "$NIX_VERSION"
add_path "$NIX_PATH_DIR"
case "${CI_PLATFORM-}" in
  gh-actions)
    sudo chown 0:0 / || true
    ;;
  azure-pipelines)
    sudo chown 0:0 / || true
    cat >> ~/.bash_profile <<EOF

#source "$NIX_PROFILE"
EOF
    ;;
esac
