{ binutils, runCommand, fpm }:
let
  sharball = import ../tarball/doit.nix;
in
runCommand "nix.deb" {
  buildInputs = [ fpm binutils ];
}
  ''
    mkdir -p $TMPDIR/usr/local/lib/nix/
    cp ${sharball} $TMPDIR/usr/local/lib/nix/bootstrap.tar.bz.sh
    fpm -s dir -t deb -n nix --post-install ${./install.sh} -p $out -C $TMPDIR usr/
  ''

