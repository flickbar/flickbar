#!/bin/sh
# Regenerates Resources/AppIcon.icns from scripts/MakeIcon.swift.
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build Resources
swiftc -O scripts/MakeIcon.swift -o .build/make-icon
.build/make-icon .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
