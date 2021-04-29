{
  description = "A very basic flake";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "i686-linux" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        });

    in {

      overlay = final: prev: {
        fixedout = final.callPackage ./. { };
        sharball = final.callPackage ./tarball { };
        nix-dpkg = final.callPackage ./dpkg { };
      };

      packages = forAllSystems (system: {
        inherit (nixpkgsFor.${system}) fixedout sharball nix-dpkg;
      });

      defaultPackage = forAllSystems (system: self.packages.${system}.fixedout);

    };
}
