#!/bin/bash
# Packages a Developer ID-signed universal build. Never substitutes an ad hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
: "${STILLDOCK_SIGN_IDENTITY:?Set STILLDOCK_SIGN_IDENTITY to a Developer ID Application identity}"
case "$STILLDOCK_SIGN_IDENTITY" in
  'Developer ID Application:'*) ;;
  *) echo 'A Developer ID Application identity is required.' >&2; exit 1 ;;
esac
STILLDOCK_VERSION="1.0.0"
STILLDOCK_APP="build/Build/Products/Release/StillDock.app"
STILLDOCK_DMG="dist/StillDock-${STILLDOCK_VERSION}-universal.dmg"
test -d "$STILLDOCK_APP"
test ! -e "$STILLDOCK_DMG"
mkdir -p dist
STILLDOCK_STAGE=$(mktemp -d "$PWD/dist/package.XXXXXX")
trap 'rm -rf "$STILLDOCK_STAGE"' EXIT
ditto "$STILLDOCK_APP" "$STILLDOCK_STAGE/StillDock.app"
STILLDOCK_KEYCHAIN_ARGS=()
if test -n "${STILLDOCK_SIGN_KEYCHAIN:-}"; then
  STILLDOCK_KEYCHAIN_ARGS=(--keychain "$STILLDOCK_SIGN_KEYCHAIN")
fi
codesign --force --sign "$STILLDOCK_SIGN_IDENTITY" "${STILLDOCK_KEYCHAIN_ARGS[@]}" --options runtime --timestamp "$STILLDOCK_STAGE/StillDock.app"
codesign --verify --deep --strict "$STILLDOCK_STAGE/StillDock.app"
lipo "$STILLDOCK_STAGE/StillDock.app/Contents/MacOS/StillDock" -verify_arch arm64 x86_64
ln -s /Applications "$STILLDOCK_STAGE/Applications"
cp docs/INSTALL.txt "$STILLDOCK_STAGE/Read Me.txt"
hdiutil create -volname 'StillDock' -srcfolder "$STILLDOCK_STAGE" -ov -format UDZO "$STILLDOCK_DMG"
codesign --sign "$STILLDOCK_SIGN_IDENTITY" "${STILLDOCK_KEYCHAIN_ARGS[@]}" --timestamp "$STILLDOCK_DMG"
echo "Created $STILLDOCK_DMG. Submit for notarization and staple before publishing."
