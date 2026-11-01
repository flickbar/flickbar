#!/bin/sh
# Prints the notes for one version from CHANGELOG.md: ./scripts/changelog-section.sh 0.12.0
# Fails when CHANGELOG.md has no section (or an empty one) for it. Same rules as Changelog.section in FlickbarCore.
set -eu
cd "$(dirname "$0")/.."
NOTES="$(awk -v v="$1" '/^## / { p = index($0, "## [" v "]") == 1; next } /^\[[^]]*\]: / { next } p' CHANGELOG.md)"
printf '%s\n' "$NOTES" | grep -q '[^[:space:]]' || { echo "CHANGELOG.md has no notes under ## [$1]." >&2; exit 1; }
# Without the blank lines around it, like the app shows it.
printf '%s\n' "$NOTES" | awk 'NF { for (; blank > 0; blank--) print ""; started = 1; print; next } started { blank++ }'
