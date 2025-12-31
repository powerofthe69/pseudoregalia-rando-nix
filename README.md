# This repo is being archived in favor of a joint repo that I have stood up that includes Nix packages for mesa-git, proton-cachyos, vintage-story, etc.

**From this point forward, the only repos that I plan to actively maintain are the [proton-cachyos-nix repository](https://github.com/powerofthe69/proton-cachyos-nix) (as it has a small overhead), and the [nix-gaming-edge repository](https://github.com/powerofthe69/nix-gaming-edge) that will actively maintain a mesa-git module and any new packages moving forward.**



This repository is used to download, compile, and install the latest version of the randomizer for Pseudoregalia in a Nix environment.

Enable this in your flake.nix inputs using `pseudoregalia-rando.url = "github:powerofthe69/pseudoregalia-rando-nix";`.

Enable the overlay using `nixpkgs.overlays = [ pseudoregalia-rando.overlays.default ];`.

To install the latest version, use:

`environment.systemPackages = with pkgs [ pseudoregalia-rando ];` or `users.users.youruser.packages = with pkgs [ pseudoregalia-rando ];`
