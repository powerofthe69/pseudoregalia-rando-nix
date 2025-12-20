{
  description = "Pseudoregalia Randomizer Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
  };

  outputs =
    {
      self,
      nixpkgs,
      crane,
    }:
    let
      # Shared data to pass to the overlay
      sourceData = builtins.fromJSON (builtins.readFile ./pkgs/sources.json);
    in
    {
      # 1. THE OVERLAY OUTPUT
      # This function tells Nix how to "inject" your package into pkgs.
      overlays.default = final: prev: {
        pseudoregalia-rando = final.callPackage ./pkgs/default.nix {
          # We must create the craneLib using the 'final' pkgs to ensure
          # glibc versions match the system we are overlaying onto.
          craneLib = crane.mkLib final;
          inherit sourceData;
        };
      };

      # 2. STANDARD PACKAGES OUTPUT
      # We can actually reuse the overlay here to define the default package!
      # This keeps your flake DRY (Don't Repeat Yourself).
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
