{ runCommand, fpm, binutils, nix, perl, pathsFromGraph, shellcheck }:
runCommand "nix.deb" {
  buildInputs = [ fpm binutils ];
  inherit nix;
  version = nix.version;
  sharball = (import ../tarball) { inherit runCommand nix perl pathsFromGraph shellcheck; };
}
  ''
    cd $TMPDIR

    # copy in the Nix bootstrap sharball
    mkdir -p usr/lib/nix/
    cp $sharball usr/lib/nix/bootstrap.tar.bz.sh

    # copy systemd unit files, rather than linking them, to avoid systemd symlink issues
    mkdir -p usr/lib/systemd/system/
    cp $nix/lib/systemd/system/nix-daemon.socket usr/lib/systemd/system/nix-daemon.socket
    cp $nix/lib/systemd/system/nix-daemon.service usr/lib/systemd/system/nix-daemon.service

    # link the binaries to standard location
    mkdir -p usr/bin
    for binary in $nix/bin/*; do
      ln -sf $binary usr/bin/;
    done

    # copy profile initialization files, rather than linking them, to allow editing in extremity
    mkdir -p etc/profile.d/
    cp $nix/etc/profile.d/nix-daemon.sh etc/profile.d/nix-daemon.sh
    cp $nix/etc/profile.d/nix.sh etc/profile.d/nix.sh

    # create garbage collector root symlink to bootstrapped version of Nix
    mkdir -p nix/var/nix/gcroots/
    ln -sf $nix nix/var/nix/gcroots/system_nix

    fpm -s dir -t deb \
        -n nix \
        -v $version \
        --deb-no-default-config-files \
        --post-install ${./install.sh} \
        -p $out usr/ etc/ nix/
  ''

