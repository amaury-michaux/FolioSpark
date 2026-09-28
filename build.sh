#!/bin/bash
# Compile and assemble build/FolioSpark.app (Xcode is not required).
# ./build.sh --install copie aussi l'app dans /Applications.
set -euo pipefail
cd "$(dirname "$0")"

# Le SDK macOS 27 des Command Line Tools déclare @State comme macro, dont le plugin
# n'est livré qu'avec Xcode : on compile contre le SDK macOS 26 s'il est présent.
SDK26="$(xcode-select -p)/SDKs/MacOSX26.sdk"
if [ -d "$SDK26" ]; then export SDKROOT="$SDK26"; fi

BUILD_PATH="${FOLIOSPARK_BUILD_PATH:-.build}"
swift build --build-path "$BUILD_PATH" -debug-info-format none -c release

APP="build/FolioSpark.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_PATH/release/Reader" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp icon/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

echo "OK → $APP"

if [ "${1:-}" = "--install" ]; then
    rm -rf "/Applications/FolioSpark.app"
    ditto "$APP" "/Applications/FolioSpark.app"
    echo "Installed → /Applications/FolioSpark.app"
fi
