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
    pkgsForSystem = system: import nixpkgs {inherit system;};
    # nix-prefetch-url --type sha256 --unpack {URL}
    #:version:
    version = "1.12.7b";
    downloadUrl = {
      "x86_64-linux" = {
        url = "${baseUrl}/${version}/zen.linux-x86_64.tar.xz";
        #:sha256:
        sha256 = "sha256:1jsz0vahnfvsa1hmaipj3cv2gglcir77yal765ipdj0f6m5qflpx";
      };
      "aarch64-linux" = {
        url = "${baseUrl}/${version}/zen.linux-aarch64.tar.xz";
        #:sha256:
        sha256 = "sha256:0vhw0jk689fl9j9zz59dna7friqq9ppjrjr1g2yaznxfmn428glk";
      };
      "aarch64-darwin" = {
        url = "${baseUrl}/${version}/zen.macos-universal.dmg";
        #:sha256:
        sha256 = "sha256:0ysa3p7sq9fh4p0gaxnlj0yf8ybmxjm48dfd49d9h244gm5lq56j";
      };
      "x86_64-darwin" = {
        url = "${baseUrl}/${version}/zen.macos-universal.dmg";
        #:sha256:
        sha256 = "sha256:0ysa3p7sq9fh4p0gaxnlj0yf8ybmxjm48dfd49d9h244gm5lq56j";
      };
    };

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
            set -x  # Enables command tracing
                      mkdir -p $out/Applications
                      ls >&2
                      cp -r "Zen.app" $out/Applications/
                        set +x  # Disables command tracing when you're done
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

    devShell = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.mkShell
      {
        packages = with pkgs; [
          statix
          nixd
          nixpkgs-fmt
          alejandra
        ];
      });
  };
}
