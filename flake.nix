{
  description = "Pseudoregalia Randomizer Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    {
      overlays.default = final: prev: {
        pseudoregalia-rando = final.callPackage ./pkgs/default.nix { };
      };

      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          default = pkgs.pseudoregalia-rando;
        }
      );
    };
}
