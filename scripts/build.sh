#!/bin/bash
set -euo pipefail

# Builds Scrollie.app from the Swift package.
# Usage: ./scripts/build.sh [--install]
#   SIGN_IDENTITY="Apple Development: ..." ./scripts/build.sh   # sign with a real identity
#
# Without SIGN_IDENTITY the app is ad-hoc signed. That works, but every rebuild gets a new
# signature, so macOS forgets the Accessibility grant: remove Scrollie from
# System Settings > Privacy & Security > Accessibility and add it again after a rebuild.

cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP_NAME="Scrollie"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
OUT_DIR="build"
APP="$OUT_DIR/$APP_NAME.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp "$APP_NAME/Info.plist" "$APP/Contents/Info.plist"

if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - "$APP"
else
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP"
fi

echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" "/Applications/$APP_NAME.app"
    echo "Installed to /Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
fi
