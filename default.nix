{ pkgs ? import <nixpkgs> {}
, python3Packages ? pkgs.python3Packages
}:

with python3Packages;
buildPythonPackage {
  name = "nix-utils";
  src = ./.;
}
