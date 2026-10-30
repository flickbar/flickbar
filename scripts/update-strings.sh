#!/bin/sh
# Adds new interface text to Resources/Localizable.xcstrings and marks text no longer used as stale.
# Then translate the new entries (Xcode opens the file in its String Catalog editor).
set -eu
cd "$(dirname "$0")/.."
OUT=.build/stringsdata
rm -rf "$OUT" && mkdir -p "$OUT"
xcrun xcstringstool extract --SwiftUI --modern-localizable-strings -o "$OUT" Sources/Flickbar/*.swift
xcrun xcstringstool sync Resources/Localizable.xcstrings --stringsdata "$OUT"/*.stringsdata
