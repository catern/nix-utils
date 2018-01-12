#!/usr/bin/env bash
set -o errexit
set -o nounset

bootstrap=/usr/lib/nix/bootstrap.tar.bz.sh
nix="$($bootstrap --print-packaged-nix-path)"

if ! test -e $nix; then
   $bootstrap
fi

# initialize per-user roots directory.  we create these here because
# these are stateful and persistent, and shouldn't be deleted if we
# remove the package.
mkdir -p --mode=00755 /nix/var/nix/gcroots
mkdir -p --mode=00755 /nix/var/nix/profiles
mkdir -p --mode=01777 /nix/var/nix/gcroots/per-user
mkdir -p --mode=01777 /nix/var/nix/profiles/per-user

# refresh the systemd services
systemctl daemon-reload
systemctl enable nix-daemon.socket
systemctl start nix-daemon.socket
# let nix-daemon get socket activated
systemctl stop nix-daemon.service
