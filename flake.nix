{
  description = "connerohnesorge/zen-browser-flake: Experience tranquillity while browsing the web without people tracking you!";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    pname = "zen-browser";
    description = "Zen Browser: Experience tranquillity while browsing the web without people tracking you!";
    supportedSystems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    pkgsForSystem = system: import nixpkgs {inherit system;};

    # Import version data from JSON file
    versionData = builtins.fromJSON (builtins.readFile ./version.json);
    inherit (versionData) version;
    downloadUrl =
      builtins.mapAttrs (platform: data: {
        inherit (data) url;
        inherit (data) sha256;
      })
      versionData.platforms;

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

        desktopSrc = self;

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
            else [wrapGAppsHook3]
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
          patchelf $out/bin/zen \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"

          wrapProgram $out/bin/zen \
            --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}" \
            --set MOZ_LEGACY_PROFILES 1 \
            --set MOZ_ALLOW_DOWNGRADE 1 \
            --set MOZ_APP_LAUNCHER zen \
            --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"

          patchelf $out/bin/zen-bin \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"

          wrapProgram $out/bin/zen-bin \
            --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}" \
            --set MOZ_LEGACY_PROFILES 1 \
            --set MOZ_ALLOW_DOWNGRADE 1 \
            --set MOZ_APP_LAUNCHER zen \
            --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH"

          patchelf $out/bin/glxtest \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"

          wrapProgram $out/bin/glxtest \
            --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}"

          patchelf --set-interpreter \
            "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/updater

          wrapProgram $out/bin/updater \
            --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}"

          patchelf $out/bin/vaapitest \
            --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"

          wrapProgram $out/bin/vaapitest \
            --set LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath (linuxRuntimeLibs pkgs)}"
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
      update = let
        pkgs = pkgsForSystem system;
      in
        pkgs.writeShellScriptBin "zen-update" ''
          set -euo pipefail

          # Colors for output
          RED='\033[0;31m'
          GREEN='\033[0;32m'
          YELLOW='\033[1;33m'
          NC='\033[0m' # No Color

          echo "Fetching latest Zen Browser release..."

          # Get latest release info
          release_data=$(${pkgs.curl}/bin/curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest)
          version=$(echo "$release_data" | ${pkgs.jq}/bin/jq -r '.tag_name')

          echo "Latest version: $version"

          # Create temporary directory for working
          work_dir=$(mktemp -d)
          trap "rm -rf $work_dir" EXIT

          # Platform mappings
          declare -A patterns=(
            ["x86_64-linux"]="zen.linux-x86_64.tar.xz"
            ["aarch64-linux"]="zen.linux-aarch64.tar.xz"
            ["aarch64-darwin"]="zen.macos-universal.dmg"
            ["x86_64-darwin"]="zen.macos-universal.dmg"
          )

          # Start building version.json
          cat > "$work_dir/version.json" <<EOF
          {
            "version": "$version",
            "platforms": {
          EOF

          platform_count=0
          total_platforms=4

          for platform in x86_64-linux aarch64-linux aarch64-darwin x86_64-darwin; do
            pattern="''${patterns[$platform]}"
            ((platform_count++))

            echo "Processing $platform..."

            # Find matching asset
            asset_url=$(echo "$release_data" | ${pkgs.jq}/bin/jq -r ".assets[] | select(.name | contains(\"$pattern\")) | .browser_download_url")

            if [[ -z "$asset_url" || "$asset_url" == "null" ]]; then
              echo -e "''${RED}Warning: No matching asset found for $platform''${NC}"
              continue
            fi

            echo "Calculating hash for $platform..."
            echo "URL: $asset_url"

            # Calculate hash based on file type
            if [[ "$asset_url" == *.dmg ]]; then
              hash_value=$(${pkgs.nix}/bin/nix-prefetch-url "$asset_url")
            else
              hash_value=$(${pkgs.nix}/bin/nix-prefetch-url --type sha256 --unpack "$asset_url")
            fi

            echo -e "''${GREEN}Hash: sha256:$hash_value''${NC}"

            # Add to JSON (with comma if not last)
            comma=""
            if [[ $platform_count -lt $total_platforms ]]; then
              comma=","
            fi

            cat >> "$work_dir/version.json" <<EOF
              "$platform": {
                "url": "$asset_url",
                "sha256": "sha256:$hash_value"
              }$comma
          EOF
          done

          # Close JSON
          cat >> "$work_dir/version.json" <<EOF
            }
          }
          EOF

          # Format JSON nicely
          ${pkgs.jq}/bin/jq . "$work_dir/version.json" > version.json

          echo -e "''${GREEN}version.json has been updated successfully!''${NC}"
          echo "New version: $version"
          echo ""
          echo "Next steps:"
          echo "1. Review the changes: git diff version.json"
          echo "2. Test the build: nix build"
          echo "3. Commit the changes: git add version.json && git commit -m \"Update to $version\""
        '';
    });

    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/zen";
      };
      update = {
        type = "app";
        program = "${self.packages.${system}.update}/bin/zen-update";
      };
    });

    devShells = forAllSystems (system: let
      pkgs = pkgsForSystem system;
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          statix
          nixd
          nixpkgs-fmt
          alejandra
        ];
      };
    });
  };
}
