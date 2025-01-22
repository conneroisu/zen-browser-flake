{
  description = "conneroisu/zen-browser-flake: Experience tranquillity while browsing the web without people tracking you!";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    baseUrl = "https://github.com/zen-browser/desktop/releases/download";
    pname = "zen-browser";
    description = "Zen Browser: Experience tranquillity while browsing the web without people tracking you!";
    supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    # nix-prefetch-url --type sha256 --unpack {URL}
    #:version:
    version = "1.7.1b";
    downloadUrl = {
      "x86_64-linux" = {
        url = "${baseUrl}/${version}/zen.linux-x86_64.tar.bz2";
        #:sha256:
        sha256 = "sha256:0yk76dbs1zy4gifs5vlqmpzypswc33nlr2n3lqdqp74zf4nf4aja";
      };
      "aarch64-linux" = {
        url = "${baseUrl}/${version}/zen.linux-aarch64.tar.bz2";
        #:sha256:
        sha256 = "sha256:1qpm59x0xwd8zy38w2za0h98n1b7kwrpwaklixkfgrx3a2f8glwz";
      };
      "aarch64-darwin" = {
        url = "${baseUrl}/${version}/zen.macos-aarch64.dmg";
        #:sha256:
        sha256 = "sha256:1309w0i2lab39c30syfsq5d8mrnvhl9nsgkp6h4jraxwc59a0azy";
      };
      "x86_64-darwin" = {
        url = "${baseUrl}/${version}/zen.macos-x86_64.dmg";
        #:sha256:
        sha256 = "sha256:1rsr9zy51bnrmdb91k9j342q3b44ymmiksxs6asrb3pax4v6bgpn";
      };
    };

    pkgsForSystem = system: import nixpkgs {inherit system;};

    linuxRuntimeLibs = pkgs:
      with pkgs;
        [
          libGL
          libGLU
          libevent
          libffi
          libjpeg
          libpng
          libstartup_notification
          libvpx
          libwebp
          stdenv.cc.cc
          fontconfig
          libxkbcommon
          zlib
          freetype
          gtk3
          libxml2
          dbus
          xcb-util-cursor
          alsa-lib
          libpulseaudio
          pango
          atk
          cairo
          gdk-pixbuf
          glib
          udev
          libva
          mesa
          libnotify
          cups
          pciutils
          ffmpeg
          libglvnd
          pipewire
        ]
        ++ (with pkgs.xorg; [
          libxcb
          libX11
          libXcursor
          libXrandr
          libXi
          libXext
          libXcomposite
          libXdamage
          libXfixes
          libXScrnSaver
        ]);

    mkZen = system: let
      pkgs = pkgsForSystem system;
      inherit (pkgs) stdenv;
      inherit (stdenv) isDarwin;
      downloadData = downloadUrl."${system}";
    in
      stdenv.mkDerivation {
        inherit version pname description;

        src =
          if isDarwin
          then
            pkgs.fetchurl {
              inherit (downloadData) url sha256;
              name = "zen-${version}.dmg";
            }
          else
            builtins.fetchTarball {
              inherit (downloadData) url sha256;
            };

        desktopSrc = ./.;

        phases =
          if isDarwin
          then ["unpackPhase" "installPhase"]
          else ["installPhase" "fixupPhase"];

        nativeBuildInputs = with pkgs;
          [
            makeWrapper
            copyDesktopItems
          ]
          ++ (
            if isDarwin
            then [undmg]
            else [wrapGAppsHook]
          );

        unpackPhase = pkgs.lib.optionalString isDarwin ''
          undmg $src
        '';

        installPhase =
          if isDarwin
          then ''
            mkdir -p $out/Applications
            cp -r "Zen Browser.app" $out/Applications/
          ''
          else ''
            mkdir -p $out/bin && cp -r $src/* $out/bin
            install -D $desktopSrc/zen.desktop $out/share/applications/zen.desktop
            install -D $src/browser/chrome/icons/default/default128.png $out/share/icons/hicolor/128x128/apps/zen.png
          '';

        fixupPhase = pkgs.lib.optionalString (!isDarwin) ''
          chmod 755 $out/bin/*
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zen
          wrapProgram $out/bin/zen --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}" \
                          --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --set MOZ_APP_LAUNCHER zen --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/zen-bin
          wrapProgram $out/bin/zen-bin --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}" \
                          --set MOZ_LEGACY_PROFILES 1 --set MOZ_ALLOW_DOWNGRADE 1 --set MOZ_APP_LAUNCHER zen --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/glxtest
          wrapProgram $out/bin/glxtest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}"
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/updater
          wrapProgram $out/bin/updater --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}"
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/vaapitest
          wrapProgram $out/bin/vaapitest --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}"
        '';

        meta = {
          mainProgram =
            if isDarwin
            then null
            else "zen";
          platforms = [system];
        };
      };
  in {
    packages = forAllSystems (system: {
      default = mkZen system;
    });
  };
}
