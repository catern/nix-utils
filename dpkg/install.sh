#!/usr/bin/env bash
set -o errexit
set -o nounset

bootstrap=/usr/local/lib/nix/bootstrap.tar.bz.sh
nix="$($bootstrap --print-packaged-nix-path)"

if ! test -e $nix; then
   ./$bootstrap
fi

mkdir -p --mode=00755 /nix/var/nix/gcroots
mkdir -p --mode=00755 /nix/var/nix/profiles
mkdir -p --mode=01777 /nix/var/nix/gcroots/per-user
mkdir -p --mode=01777 /nix/var/nix/profiles/per-user

# update system_nix garbage collector root to latest version of $nix
ln -sf $nix /nix/var/nix/gcroots/system_nix

# update systemd file links
ln -sf $nix/lib/systemd/system/nix-daemon.service /etc/systemd/system/nix-daemon.service
ln -sf $nix/lib/systemd/system/nix-daemon.socket /etc/systemd/system/nix-daemon.socket

systemctl daemon-reload
systemctl enable nix-daemon.socket
systemctl start nix-daemon.socket
# let it get socket activated
systemctl stop nix-daemon.service

# profile initialization files
ln -sf $nix/etc/profile.d/nix-daemon.sh /etc/profile.d/nix-daemon.sh
ln -sf $nix/etc/profile.d/nix.sh /etc/profile.d/nix.sh

# install this version of Nix to the root profile so users can find the Nix tools
$nix/bin/nix-env -p /nix/var/nix/profiles/default -i $nix
