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
# The icon is an Icon Composer document (open Resources/AppIcon.icon in Xcode's Icon Composer to edit it).
# actool turns it into Assets.car for macOS 26's Liquid Glass and AppIcon.icns for earlier systems.
xcrun actool Resources/AppIcon.icon --compile "$APP/Contents/Resources" --platform macosx \
    --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist "$(dirname "$BIN")/icon.plist" >/dev/null
# actool exits 0 without writing anything when the path or icon name is wrong. (Its partial Info.plist isn't
# read: the two icon keys it holds are written below.)
[ -f "$APP/Contents/Resources/Assets.car" ] || { echo "actool produced no icon" >&2; exit 1; }
cp "$BIN" "$APP/Contents/MacOS/Flickbar"
# Dependencies' resource bundles (KeyboardShortcuts' translations) go where Bundle.module looks in an app.
find "$(dirname "$BIN")" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;
# Sparkle's framework, found by the rpath set in Package.swift.
mkdir -p "$APP/Contents/Frameworks"
ditto "$(dirname "$BIN")/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp .build/checkouts/Sparkle/LICENSE "$APP/Contents/Resources/Sparkle-LICENSE.txt"
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
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>SUFeedURL</key><string>https://flickbar.github.io/appcast.xml</string>
    <key>SUPublicEDKey</key><string>BL9HHXETCB4Yv4FIyToTMN5W6Sb/DUA2nVcjX66/ZDc=</string>
    <key>SUEnableAutomaticChecks</key><false/>
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
    sign() { codesign --force --options runtime ${SIGN_TIMESTAMP:+--timestamp} --sign "$IDENTITY" "$@"; }
    # Inside out, as Sparkle's docs ask: its helpers, then the framework, then the app.
    SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
    sign "$SPARKLE/XPCServices/Installer.xpc"
    sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
    sign "$SPARKLE/Autoupdate" "$SPARKLE/Updater.app" "$APP/Contents/Frameworks/Sparkle.framework"
    sign "$APP"
    echo "Signed with $IDENTITY"
else
    echo "warning: no valid signing identity; ad-hoc signing (re-grant Accessibility after each build)" >&2
    codesign --force --sign - "$APP"
fi
echo "Built $APP"
