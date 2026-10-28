#!/bin/sh
# Builds a release binary and wraps it in build/Flickbar.app (ad-hoc signed).
set -eu
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Flickbar"

APP="${APP:-build/Flickbar.app}"
mkdir -p "$(dirname "$APP")"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN" "$APP/Contents/MacOS/Flickbar"

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
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Flickbar contributors. GPL-3.0-or-later.</string>
</dict>
</plist>
EOF

# macOS ties the Accessibility grant to the signature. Ad-hoc signatures change on every build, so the grant
# silently stops applying; a stable identity (see README) keeps it across rebuilds.
# Uses $SIGN_IDENTITY, else the first valid (unexpired) Developer ID / Apple Development / local identity.
# Picks the SHA-1 hash, since an expired certificate can share the same name and make the name ambiguous.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning |
    awk '/"(Developer ID Application|Apple Development|Flickbar Local Signing)/ { print $2; exit }')}"
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
    echo "Signed with $IDENTITY"
else
    echo "warning: no valid signing identity; ad-hoc signing (re-grant Accessibility after each build)" >&2
    codesign --force --sign - "$APP"
fi
echo "Built $APP"
