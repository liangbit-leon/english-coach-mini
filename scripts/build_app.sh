#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/English Coach Mini.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$PROJECT_DIR"
swift build -c release

if [[ "$APP_DIR" != "$PROJECT_DIR/dist/English Coach Mini.app" ]]; then
    print -u2 "Unexpected app output path"
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$PROJECT_DIR/.build/release/EnglishCoachMini" "$MACOS_DIR/EnglishCoachMini"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

codesign --force --deep --sign - "$APP_DIR"
print "$APP_DIR"
