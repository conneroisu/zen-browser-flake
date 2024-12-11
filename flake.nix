{
  description = "Zen Browser";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    version = "1.0.2-b.0";
    downloadUrl = {
      "specific" = {
        url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-specific.tar.bz2";
        # https://github.com/zen-browser/desktop/releases/download/1.0.2-b.0/zen.linux-specific.tar.bz2
        # nix-prefetch-url --type sha256  --unpack https://github.com/zen-browser/desktop/releases/download/1.0.2-b.0/zen.linux-specific.tar.bz2
        sha256 = "sha256:067m7g48nfa366ajn3flphnwkx8msc034r6px8ml66mbj7awjw4x";
      };
      "aarch64-darwin" = {
        url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.macos-aarch64.dmg";
        # https://github.com/zen-browser/desktop/releases/download/1.0.2-b.0/zen.macos-aarch64.dmg
        # nix-prefetch-url --type sha256  https://github.com/zen-browser/desktop/releases/download/1.0.2-b.0/zen.macos-aarch64.dmg
        sha256 = "sha256:0zflacn4p556j52v9i2znj415ar46kv1h7i18wqg2i2kvcs53kav";
      };
      "x86_64-darwin" = {
        url = "https://github.com/zen-browser/desktop/releases/download/${version}/zen.macos-x86_64.dmg";
        # https://github.com/zen-browser/desktop/releases/download/1.0.2-b.0/zen.macos-x86_64.dmg
        # nix-prefetch-url  https://github.com/zen-browser/desktop/releases/download/1.0.2-b.0/zen.macos-x86_64.dmg
        sha256 = "sha256:19i8kdn0i9m0amc9g7h88pf798v13h3nidw7k4x2s8axgyy5zmbg";
      };
    };

    pkgsForSystem = system: import nixpkgs { inherit system; };

    linuxRuntimeLibs = pkgs: with pkgs;
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
      isDarwin = pkgs.stdenv.isDarwin;
      variant = if isDarwin then system else "specific";
      downloadData = downloadUrl."${variant}";
    in
      pkgs.stdenv.mkDerivation {
        inherit version;
        pname = "zen-browser";

        src = if isDarwin
          then pkgs.fetchurl {
            inherit (downloadData) url sha256;
            name = "zen-${version}.dmg";
          }
          else builtins.fetchTarball {
            inherit (downloadData) url sha256;
          };

        desktopSrc = ./.;

        phases = if isDarwin
          then [ "unpackPhase" "installPhase" ]
          else [ "installPhase" "fixupPhase" ];

        nativeBuildInputs = with pkgs; [
          makeWrapper
          copyDesktopItems
        ] ++ (if isDarwin
          then [ undmg ]
          else [ wrapGAppsHook ]);

        unpackPhase = pkgs.lib.optionalString isDarwin ''
          undmg $src
        '';

        installPhase = if isDarwin then ''
          mkdir -p $out/Applications
          cp -r "Zen Browser.app" $out/Applications/
        '' else ''
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
          mainProgram = if isDarwin then null else "zen";
          platforms = [ system ];
        };
      };
  in {
    packages = forAllSystems (system: {
      default = mkZen system;
    });
  };
}
