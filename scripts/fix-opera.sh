#!/bin/bash

if [[ $(id -u) -ne 0 ]]; then
  printf 'Try to run it with sudo\n'
  exit 1
fi

if [[ $(uname -m) != "x86_64" ]]; then
  printf 'This script is intended for 64-bit systems\n'
  exit 1
fi

for bin in unzip bsdtar curl jq; do
  if ! command -v "$bin" > /dev/null; then
    printf '\033[1m%s\033[0m package must be installed to run this script\n' "$bin"
    exit 1
  fi
done

ARCH_SYSTEM=false
if command -v pacman &> /dev/null; then
  ARCH_SYSTEM=true
fi

# Config
readonly FIX_WIDEVINE=true
readonly FIX_DIR='/tmp/opera-fix'
readonly FFMPEG_SRC_MAIN='https://api.github.com/repos/Ld-Hagen/nwjs-ffmpeg-prebuilt/releases'
readonly FFMPEG_SRC_ALT='https://api.github.com/repos/Ld-Hagen/fix-opera-linux-ffmpeg-widevine/releases'
readonly WIDEVINE_SRC='https://raw.githubusercontent.com/mozilla-firefox/firefox/refs/heads/main/toolkit/content/gmp-sources/widevinecdm.json'
readonly FFMPEG_SO_NAME='libffmpeg.so'
readonly WIDEVINE_SO_NAME='libwidevinecdm.so'
readonly WIDEVINE_MANIFEST_NAME='manifest.json'

OPERA_VERSIONS=()
[[ -x "$(command -v opera)" ]] && OPERA_VERSIONS+=("opera")
[[ -x "$(command -v opera-beta)" ]] && OPERA_VERSIONS+=("opera-beta")

printf 'Getting download links...\n'

# ffmpeg
readonly FFMPEG_URL_MAIN=$(curl -sL4 "$FFMPEG_SRC_MAIN" | jq -rS 'sort_by(.published_at) | .[-1].assets[0].browser_download_url')
readonly FFMPEG_URL_ALT=$(curl -sL4 "$FFMPEG_SRC_ALT" | jq -rS 'sort_by(.published_at) | .[-1].assets[0].browser_download_url')
if [[ $(basename "$FFMPEG_URL_ALT") < $(basename "$FFMPEG_URL_MAIN") ]]; then
  readonly FFMPEG_URL="$FFMPEG_URL_MAIN"
else
  readonly FFMPEG_URL="$FFMPEG_URL_ALT"
fi
[[ -z "$FFMPEG_URL" ]] && { printf 'Failed to get ffmpeg download URL. Exiting...\n'; exit 1; }

# Widevine
if $FIX_WIDEVINE; then
  readonly WIDEVINE_URL=$(curl -sL4 "$WIDEVINE_SRC" | jq -r '.vendors."gmp-widevinecdm".platforms."Linux_x86_64-gcc3".fileUrl')
  [[ -z "$WIDEVINE_URL" || "$WIDEVINE_URL" == "null" ]] && { printf 'Failed to get Widevine download URL. Exiting...\n'; exit 1; }
fi

# Downloading files
printf 'Downloading files...\n'
mkdir -p "$FIX_DIR"

curl -L4 --progress-bar "$FFMPEG_URL" -o "$FIX_DIR/ffmpeg.zip" || { printf 'Failed to download ffmpeg.\n'; exit 1; }

if $FIX_WIDEVINE; then
  curl -L4 --progress-bar "$WIDEVINE_URL" -o "$FIX_DIR/widevine.crx3" || { printf 'Failed to download WidevineCDM.\n'; exit 1; }
fi

# Extracting files
printf 'Extracting ffmpeg...\n'
unzip -o "$FIX_DIR/ffmpeg.zip" -d "$FIX_DIR" > /dev/null

if $FIX_WIDEVINE; then
  printf 'Extracting WidevineCDM...\n'
  bsdtar -xf "$FIX_DIR/widevine.crx3" -C "$FIX_DIR"
fi

# Install libs
for opera in "${OPERA_VERSIONS[@]}"; do
  printf 'Processing %s...\n' "$opera"
  EXECUTABLE=$(command -v "$opera")
  if $ARCH_SYSTEM; then
    OPERA_DIR=$(dirname "$(grep exec "$EXECUTABLE" | cut -d ' ' -f2)")
  else
    OPERA_DIR=$(dirname "$(readlink -f "$EXECUTABLE")")
  fi

  OPERA_LIB_DIR="$OPERA_DIR/lib_extra"
  OPERA_WIDEVINE_DIR="$OPERA_LIB_DIR/WidevineCdm"
  OPERA_WIDEVINE_SO_DIR="$OPERA_WIDEVINE_DIR/_platform_specific/linux_x64"
  OPERA_WIDEVINE_CONFIG="$OPERA_DIR/resources/widevine_config.json"

  printf 'Removing old libraries & preparing directories...\n'
  rm -f "$OPERA_LIB_DIR/$FFMPEG_SO_NAME"
  mkdir -p "$OPERA_LIB_DIR"

  if $FIX_WIDEVINE; then
    rm -rf "$OPERA_WIDEVINE_DIR"
    mkdir -p "$OPERA_WIDEVINE_SO_DIR"
  fi

  printf 'Copying libraries to Opera directories...\n'
  cp -f "$FIX_DIR/$FFMPEG_SO_NAME" "$OPERA_LIB_DIR"
  chmod 0644 "$OPERA_LIB_DIR/$FFMPEG_SO_NAME"

  if $FIX_WIDEVINE; then
    cp -f "$FIX_DIR/_platform_specific/linux_x64/$WIDEVINE_SO_NAME" "$OPERA_WIDEVINE_SO_DIR"
    chmod 0644 "$OPERA_WIDEVINE_SO_DIR/$WIDEVINE_SO_NAME"
    cp -f "$FIX_DIR/$WIDEVINE_MANIFEST_NAME" "$OPERA_WIDEVINE_DIR"
    chmod 0644 "$OPERA_WIDEVINE_DIR/$WIDEVINE_MANIFEST_NAME"

    printf '[\n  {\n    "preload": "%s"\n  }\n]\n' "$OPERA_WIDEVINE_DIR" > "$OPERA_WIDEVINE_CONFIG"
  fi
done

# Clean up
printf 'Removing temporary files...\n'
rm -rf "$FIX_DIR"

