#!/bin/sh
# Wraps an app in a drag-to-Applications disk image: ./scripts/dmg.sh build/release/Flickbar.app out.dmg
# Lays out the window with Finder, so it needs a logged-in session (and Finder automation permission once).
set -eu
cd "$(dirname "$0")/.."
APP="$1"
DMG="$2"
WORK="$(mktemp -d)"
MNT=""
trap '[ -n "$MNT" ] && hdiutil detach -quiet -force "$MNT"; rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src/.background"
ditto "$APP" "$WORK/src/Flickbar.app"
ln -s /Applications "$WORK/src/Applications"
swift scripts/dmg-background.swift "$WORK/bg.png" "$WORK/bg@2x.png"
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/src/.background/background.tiff" 2>/dev/null

hdiutil create -quiet -volname Flickbar -srcfolder "$WORK/src" -fs HFS+ -format UDRW -size 64m "$WORK/rw.dmg"
# A Flickbar volume that's already mounted would take the name Finder looks the window up by.
[ ! -e /Volumes/Flickbar ] || { echo "Eject the mounted Flickbar disk image first." >&2; exit 1; }
MNT="$(hdiutil attach -readwrite -noverify -noautoopen "$WORK/rw.dmg" | awk -F'\t' '/\/Volumes\// { print $NF }')"
# Finder needs a moment to notice the new disk.
sleep 2

osascript <<'EOF'
tell application "Finder"
    tell disk "Flickbar"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        -- 400 points of background plus the title bar
        set bounds of container window to {200, 120, 800, 548}
        set opts to icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 13
        set background picture of opts to file ".background:background.tiff"
        set position of item "Flickbar.app" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
# Finder writes the layout to .DS_Store on its own schedule; ejecting before then loses it.
i=0; while [ ! -s "$MNT/.DS_Store" ] && [ $i -lt 30 ]; do sleep 1; i=$((i+1)); done
sleep 2

# The disk's own icon in the window title, sidebar and desktop (hdiutil and Finder's layout step both drop it, so it goes in last).
cp "$APP/Contents/Resources/AppIcon.icns" "$MNT/.VolumeIcon.icns"
SetFile -a C "$MNT"
rm -rf "$MNT/.fseventsd"
sync
hdiutil detach -quiet "$MNT"
MNT=""
rm -f "$DMG"
hdiutil convert -quiet "$WORK/rw.dmg" -format ULFO -o "$DMG"
echo "Built $DMG"
