#!/bin/sh
# End-to-end test of the running Flickbar with synthetic trackpad gestures.
# Opens and closes its own TextEdit document, but moves windows and the pointer while it runs.
# The terminal running this needs Accessibility permission (to post events).
set -eu
cd "$(dirname "$0")/.."
pgrep -qf 'Flickbar.app/Contents/MacOS/Flickbar' || { echo "Flickbar is not running (open build/Flickbar.app)"; exit 1; }
mkdir -p .build
swiftc -O scripts/LiveTest.swift -o .build/livetest
.build/livetest
