This repository is used to download, compile, and install the latest version of the randomizer for Pseudoregalia in a Nix environment.

Enable this in your flake.nix inputs using `pseudoregalia-rando.url = "github:powerofthe69/pseudoregalia-rando-nix";`.

Enable the overlay using `nixpkgs.overlays = [ pseudoregalia-rando.overlays.default ];`.

To install the latest version, use:

`environment.systemPackages = with pkgs [ pseudoregalia-rando ];` or `users.users.youruser.packages = with pkgs [ pseudoregalia-rando ];`
