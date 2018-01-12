{ runCommand, nix, perl, pathsFromGraph, shellcheck, fpm, binutils }:
let
  sharball = import ../tarball/doit.nix;
in
runCommand "nix.deb" {
  buildInputs = [ fpm binutils ];
}
  ''
    nix=${nix}
    cd $TMPDIR

    # copy in the Nix bootstrap sharball
    mkdir -p usr/lib/nix/
    cp ${sharball} usr/lib/nix/bootstrap.tar.bz.sh

    # create links to systemd unit files
    mkdir -p usr/lib/systemd/system/
    ln -sf $nix/lib/systemd/system/nix-daemon.socket usr/lib/systemd/system/nix-daemon.socket
    ln -sf $nix/lib/systemd/system/nix-daemon.service usr/lib/systemd/system/nix-daemon.service

    # create links to binaries
    mkdir -p usr/bin
    for binary in $nix/bin/*; do
      ln -sf $binary usr/bin/;
    done

    # create links to profile initialization files
    mkdir -p etc/profile.d/
    ln -sf $nix/etc/profile.d/nix-daemon.sh etc/profile.d/nix-daemon.sh
    ln -sf $nix/etc/profile.d/nix.sh etc/profile.d/nix.sh

    # create garbage collector root to bootstrapped version of Nix
    mkdir -p nix/var/nix/gcroots/
    ln -sf $nix nix/var/nix/gcroots/system_nix

    fpm -s dir -t deb -n nix --deb-no-default-config-files --post-install ${./install.sh} -p $out usr/ etc/ nix/
  ''

