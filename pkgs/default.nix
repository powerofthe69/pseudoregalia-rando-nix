{
  pkgs,
  lib,
  fetchFromGitHub,
  rustPlatform,
  ...
}:

let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  runtimeDeps = with pkgs; [
    libxkbcommon
    libGL
    fontconfig
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    atk
    gtk3
    pango
    glib
    gdk-pixbuf
    cairo
    stdenv.cc.cc.lib
    zstd
  ];

  oodleLib = pkgs.fetchurl {
    url = sources.oodleLib.url;
    hash = sources.oodleLib.hash;
  };

  oodleDir =
    pkgs.runCommand "oodle-dir" { }
      "mkdir $out; ln -s ${oodleLib} $out/liboo2corelinux64.so";

  remoteSrc = fetchFromGitHub {
    owner = sources.rando.owner;
    repo = sources.rando.repo;
    rev = sources.rando.version;
    sha256 = sources.rando.hash;
  };

  patchedSrc = pkgs.runCommand "source-with-local-lock" { } ''
    cp -r ${remoteSrc} $out
    chmod -R u+w $out
    cp ${./Cargo.lock} $out/Cargo.lock
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "pseudoregalia-rando";
    desktopName = "Pseudoregalia Randomizer";
    exec = "pseudoregalia-rando";
    icon = "sybil";
    categories = [
      "Game"
      "Utility"
    ];
  };

  # Key format is "name-version"
  outputHashes = lib.mapAttrs' (
    name: value: lib.nameValuePair "${value.repo}-${value.version}" value.hash
  ) (lib.filterAttrs (n: v: n != "rando" && n != "oodleLib" && v ? repo && v ? version) sources);

in
rustPlatform.buildRustPackage {
  pname = "pseudoregalia-rando";
  version = sources.rando.version;
  src = patchedSrc;

  cargoLock = {
    lockFile = ./Cargo.lock;
    inherit outputHashes;
  };

  strictDeps = true;

  ZSTD_SYS_USE_PKG_CONFIG = "1";
  RUSTFLAGS = "-L native=${oodleDir} -l dylib=oo2corelinux64";

  nativeBuildInputs = with pkgs; [
    pkg-config
    makeWrapper
    copyDesktopItems
    patchelf
    wrapGAppsHook3
  ];

  buildInputs = runtimeDeps;

  desktopItems = [ desktopItem ];

  postInstall = ''
    patchelf \
      --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
      --set-rpath "${lib.makeLibraryPath runtimeDeps}:$out/lib" \
      $out/bin/pseudoregalia-rando

    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${./sybil.png} $out/share/icons/hicolor/256x256/apps/sybil.png

    mkdir -p $out/share/pseudoregalia-rando
    cp $out/bin/pseudoregalia-rando $out/share/pseudoregalia-rando/pseudoregalia-rando-bin
    cp ${oodleLib} $out/share/pseudoregalia-rando/liboo2corelinux64.so

    if [ -d "$src/assets" ]; then
      cp -r $src/assets $out/share/pseudoregalia-rando/assets
    elif [ -d "$src/src/assets" ]; then
      cp -r $src/src/assets $out/share/pseudoregalia-rando/assets
    fi

    chmod -R u+w $out/share/pseudoregalia-rando/assets

    mkdir -p $out/lib
    cp ${oodleLib} $out/lib/liboo2corelinux64.so

    cat > $out/bin/pseudoregalia-rando <<'WRAPPER'
    #!/bin/sh
    set -e
    USER_DIR="$HOME/.local/share/pseudoregalia-rando"
    mkdir -p "$USER_DIR"
    cp -rf --no-preserve=mode,ownership "@out@/share/pseudoregalia-rando/"* "$USER_DIR/"
    chmod +x "$USER_DIR/pseudoregalia-rando-bin"
    chmod +w "$USER_DIR/liboo2corelinux64.so"
    export LD_LIBRARY_PATH="$USER_DIR:${lib.makeLibraryPath runtimeDeps}:$out/lib:$LD_LIBRARY_PATH"
    cd "$USER_DIR"
    exec ./pseudoregalia-rando-bin "$@"
    WRAPPER

    substituteInPlace $out/bin/pseudoregalia-rando --replace "@out@" "$out"
    chmod +x $out/bin/pseudoregalia-rando
  '';

  dontPatchELF = true;
  dontStrip = true;

  meta = with lib; {
    description = "Pseudoregalia Randomizer";
    homepage = "https://github.com/${sources.rando.owner}/${sources.rando.repo}";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "pseudoregalia-rando";
  };
}
