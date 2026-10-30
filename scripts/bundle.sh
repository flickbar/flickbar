#!/bin/sh
# Builds a release binary and wraps it in build/Flickbar.app (ad-hoc signed).
set -eu
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.9.0}"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Flickbar"

APP="${APP:-build/Flickbar.app}"
mkdir -p "$(dirname "$APP")"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN" "$APP/Contents/MacOS/Flickbar"
# Dependencies' resource bundles (KeyboardShortcuts' translations) go where Bundle.module looks in an app.
find "$(dirname "$BIN")" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;
# The MIT license asks for its notice to ship with copies.
cp .build/checkouts/KeyboardShortcuts/license "$APP/Contents/Resources/KeyboardShortcuts-LICENSE.txt"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Flickbar</string>
    <key>CFBundleIdentifier</key><string>io.github.flickbar.Flickbar</string>
    <key>CFBundleName</key><string>Flickbar</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Parsa Kamalipour and Flickbar contributors. GPL-3.0-or-later.</string>
</dict>
</plist>
EOF

# macOS ties the Accessibility grant to the signature. Ad-hoc signatures change on every build, so the grant
# silently stops applying; a stable identity (see README) keeps it across rebuilds.
# Uses $SIGN_IDENTITY, else a valid (unexpired) Developer ID, else Apple Development, else a local identity.
# Developer ID first so local builds share the Accessibility grant with installed releases.
# Picks the SHA-1 hash, since an expired certificate can share the same name and make the name ambiguous.
identity() { security find-identity -v -p codesigning | awk -v name="\"$1" 'index($0, name) { print $2; exit }'; }
IDENTITY="${SIGN_IDENTITY:-$(identity "Developer ID Application")}"
IDENTITY="${IDENTITY:-$(identity "Apple Development")}"
IDENTITY="${IDENTITY:-$(identity "Flickbar Local Signing")}"
if [ -n "$IDENTITY" ]; then
    # Hardened runtime, and a secure timestamp when asked (both required for notarization).
    codesign --force --options runtime ${SIGN_TIMESTAMP:+--timestamp} --sign "$IDENTITY" "$APP"
    echo "Signed with $IDENTITY"
else
    echo "warning: no valid signing identity; ad-hoc signing (re-grant Accessibility after each build)" >&2
    codesign --force --sign - "$APP"
fi
echo "Built $APP"
