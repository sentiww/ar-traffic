{
  description = "Unity (Hub) + Android (ARCore via AR Foundation) dev env on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      unityRuntimeLibs = pkgs: with pkgs; [
        # Graphics / windowing
        libglvnd
        vulkan-loader
        xorg.libX11
        xorg.libXcursor
        xorg.libXi
        xorg.libXrandr
        xorg.libXext
        xorg.libXrender
        xorg.libXfixes
        xorg.libxcb

        # Common native deps Unity/Hub often expects
        zlib
        glib
        gdk-pixbuf
        gtk3
        alsa-lib
        pulseaudio
        libuuid
        libxml2
        openssl
        curl
      ];

      perSystemOutputs = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };

          unityhubWithCacheClear = pkgs.writeShellScriptBin "unityhub" ''
            set -euo pipefail
            cacheBase="$HOME/.config/unityhub"
            clean_path() {
              local target="$cacheBase/$1"
              if [ -e "$target" ]; then
                rm -rf "$target"
              fi
            }
            clean_path "graphqlCache"
            clean_path "releases.json"
            clean_path "Cache"
            clean_path "Code Cache"
            clean_path "GPUCache"

            desktop_dir="$HOME/.local/share/applications"
            desktop_file="$desktop_dir/unityhub-devshell.desktop"
            mkdir -p "$desktop_dir"
            script_path="$(readlink -f "$0")"
            cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=Unity Hub (dev shell)
Comment=Unity Hub launched from the project devShell
Exec=''${script_path} %u
Terminal=false
Type=Application
Icon=unityhub
Categories=Development;
MimeType=x-scheme-handler/unityhub;
EOF
            chmod 644 "$desktop_file"
            xdg-mime default "$(basename "$desktop_file")" x-scheme-handler/unityhub >/dev/null 2>&1 || true

            exec ${pkgs.unityhub}/bin/unityhub "$@"
          '';

          # Android SDK/NDK in the shell. androidenv is the standard Nix approach. :contentReference[oaicite:3]{index=3}
          androidComposition = pkgs.androidenv.composeAndroidPackages {
            platformVersions = [ "35" ];
            buildToolsVersions = [ "35.0.0" ];
            includeNDK = true;
            # If you need a specific NDK, pin here; otherwise it will track nixpkgs updates.
            # (composeAndroidPackages versions track latest on unstable.) :contentReference[oaicite:4]{index=4}
          };
          androidSdk = androidComposition.androidsdk;

          ldPath = pkgs.lib.makeLibraryPath (unityRuntimeLibs pkgs);
          androidHome = "${androidSdk}/libexec/android-sdk";
        in
          {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              unityhubWithCacheClear
              nix-ld

              openjdk17
              gradle
              git
              unzip
              which

              androidSdk
            ];

            ANDROID_HOME = androidHome;
            ANDROID_SDK_ROOT = androidHome;
            JAVA_HOME = pkgs.openjdk17.home;

            # Make running Hub/Editor binaries less painful in-shell.
            NIX_LD = pkgs.stdenv.cc.bintools.dynamicLinker;
            NIX_LD_LIBRARY_PATH = ldPath;

            shellHook = ''
              export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
              echo "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
              echo "JAVA_HOME=$JAVA_HOME"
            '';
          };
        });
    in
    {
      nixosModules.default = { config, pkgs, lib, ... }:
        {
          nixpkgs.config.allowUnfree = true;

          # Needed for "adb devices" to work as an unprivileged user (udev rules + group).
          programs.adb.enable = true; # add yourself to adbusers in your host config
          # NixOS docs: users must be in adbusers group. :contentReference[oaicite:1]{index=1}

          # Helps run non-Nix-patched binaries (Unity Editor installed by Hub) on NixOS.
          programs.nix-ld.enable = true;
          programs.nix-ld.libraries = unityRuntimeLibs pkgs;
          # Nix-ld overview. :contentReference[oaicite:2]{index=2}
        };
    }
    // perSystemOutputs;
}
