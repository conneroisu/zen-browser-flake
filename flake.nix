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
    version = "1.8b";
    downloadUrl = {
      "x86_64-linux" = {
        url = "${baseUrl}/${version}/zen.linux-x86_64.tar.xz";
        #:sha256:
        sha256 = "sha256:0x034npapnyndflhaiqk8s0wldggs4hlwhnsllq6q4vgcq2l2mwi";
      };
      "aarch64-linux" = {
        url = "${baseUrl}/${version}/zen.linux-aarch64.tar.xz";
        #:sha256:
        sha256 = "sha256:0iqfia3q8f1pk24cvcr0y86a8z8ysksi1yij9n1yd3fnd6hqhc8s";
      };
      "aarch64-darwin" = {
        url = "${baseUrl}/${version}/zen.macos-universal.dmg";
        #:sha256:
        sha256 = "sha256:0gzp1q72nccgagq7sf0z3wc15rfmwn2k2l6nqfkyyk6mk60j00mw";
      };
      "x86_64-darwin" = {
        url = "${baseUrl}/${version}/zen.macos-universal.dmg";
        #:sha256:
        sha256 = "sha256:0gzp1q72nccgagq7sf0z3wc15rfmwn2k2l6nqfkyyk6mk60j00mw";
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
            ls
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
