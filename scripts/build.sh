#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcodegen generate
xcodebuild -project StillDock.xcodeproj -scheme StillDock -configuration Release -derivedDataPath build -destination 'generic/platform=macOS' ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- build
codesign --verify --deep --strict build/Build/Products/Release/StillDock.app
