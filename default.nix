let
  pkgs = import ./pkgs.nix;
in
{
  tarball = pkgs.callPackage (import ./tarball) {};
  dpkg = pkgs.callPackage (import ./dpkg) {};
}
