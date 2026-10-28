#!/bin/sh
# Builds a release binary and wraps it in build/Flickbar.app (ad-hoc signed).
set -eu
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Flickbar"

APP=build/Flickbar.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Flickbar"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Flickbar</string>
    <key>CFBundleIdentifier</key><string>io.github.flickbar.Flickbar</string>
    <key>CFBundleName</key><string>Flickbar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Flickbar contributors. GPL-3.0-or-later.</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"
