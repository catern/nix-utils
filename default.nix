{ pkgs ? import <nixpkgs> {} }:

with pkgs.python37Packages;
buildPythonPackage {
  name = "nix-utils";
  src = ./.;
}
