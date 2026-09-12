#!/bin/bash
# Explicitly labeled development preview. This does not claim Developer ID signing or notarization.
set -euo pipefail
cd "$(dirname "$0")/.."
STILLDOCK_PREVIEW_DMG="dist/StillDock-1.0.0-preview.1-unnotarized.dmg"
test ! -e "$STILLDOCK_PREVIEW_DMG"
mkdir -p dist
STILLDOCK_PREVIEW_STAGE=$(mktemp -d "$PWD/dist/preview.XXXXXX")
trap 'rm -rf "$STILLDOCK_PREVIEW_STAGE"' EXIT
ditto build/Build/Products/Release/StillDock.app "$STILLDOCK_PREVIEW_STAGE/StillDock.app"
codesign --verify --deep --strict "$STILLDOCK_PREVIEW_STAGE/StillDock.app"
lipo "$STILLDOCK_PREVIEW_STAGE/StillDock.app/Contents/MacOS/StillDock" -verify_arch arm64 x86_64
ln -s /Applications "$STILLDOCK_PREVIEW_STAGE/Applications"
{
  cat docs/PREVIEW.txt
  cat docs/INSTALL.txt
} > "$STILLDOCK_PREVIEW_STAGE/Read Me.txt"
hdiutil create -volname 'StillDock Preview - Not Notarized' -srcfolder "$STILLDOCK_PREVIEW_STAGE" -format UDZO "$STILLDOCK_PREVIEW_DMG"
hdiutil verify "$STILLDOCK_PREVIEW_DMG"
