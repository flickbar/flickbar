#!/bin/sh
# Publishes a release from main: ./scripts/release.sh 0.6.0 notes.md
# notes.md holds what's new; the install steps and checksum are added here. Bumps the version, builds a
# universal app, tags, creates the GitHub release and points the Homebrew cask (flickbar/homebrew-tap) at it.
set -eu
cd "$(dirname "$0")/.."
VERSION="$1"
NOTES="$2"
[ -z "$(git status --porcelain)" ] || { echo "Commit or stash your changes first." >&2; exit 1; }
[ "$(git branch --show-current)" = main ] || { echo "Release from main." >&2; exit 1; }

sed -i '' "s/VERSION=\"\${VERSION:-[0-9.]*}\"/VERSION=\"\${VERSION:-$VERSION}\"/" scripts/bundle.sh
sed -i '' "s/Flickbar-[0-9.]*[0-9]\.zip/Flickbar-$VERSION.zip/" README.md
grep -q "VERSION:-$VERSION}" scripts/bundle.sh || { echo "Couldn't set the version in bundle.sh." >&2; exit 1; }
git commit -qam "Version $VERSION"

# With a Developer ID certificate the app is notarized, so it opens without Gatekeeper's warning; that needs the
# notary credentials stored once with `xcrun notarytool store-credentials flickbar-notary`. Otherwise a dedicated
# self-signed identity keeps the signature (and so users' Accessibility grant) the same across releases.
# Never the personal Apple Development certificate: its name holds the developer's email.
APP=build/release/Flickbar.app
ZIP="build/release/Flickbar-$VERSION.zip"
IDENTITY="$(security find-identity -v -p codesigning | awk '/"Developer ID Application/ { print $2; exit }')"
if [ -n "$IDENTITY" ]; then
    xcrun notarytool history --keychain-profile flickbar-notary >/dev/null 2>&1 ||
        { echo "Store the notary credentials first: xcrun notarytool store-credentials flickbar-notary" >&2; exit 1; }
    APP="$APP" SIGN_IDENTITY="$IDENTITY" SIGN_TIMESTAMP=1 ./scripts/bundle.sh
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile flickbar-notary --wait | tee build/release/notary.log
    grep -q "status: Accepted" build/release/notary.log || { echo "Notarization failed; see build/release/notary.log" >&2; exit 1; }
    # Stapling the ticket lets the app pass Gatekeeper offline too; zip again so the download has it.
    xcrun stapler staple "$APP"
    spctl --assess --type execute "$APP"
    NOTARIZED=yes
else
    IDENTITY="$(security find-identity -p codesigning | awk '/"Flickbar Release"/ { print $2; exit }')"
    [ -n "$IDENTITY" ] || echo "warning: no \"Flickbar Release\" identity; signing ad-hoc" >&2
    APP="$APP" SIGN_IDENTITY="${IDENTITY:--}" ./scripts/bundle.sh
    NOTARIZED=
fi
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
TAPPED="$(gh repo view flickbar/homebrew-tap --json name >/dev/null 2>&1 && echo yes || true)"
BREW="${TAPPED:+With [Homebrew](https://brew.sh): \`brew install --cask flickbar/tap/flickbar\` (or \`brew upgrade flickbar\`).

Or download}"

{
    cat "$NOTES"
    cat <<EOF

### Install

${BREW:-Download} **Flickbar-$VERSION.zip** below, unzip it, and move **Flickbar.app** to Applications.

${NOTARIZED:+Open Flickbar.app. }${NOTARIZED:-Flickbar isn't notarized by Apple, so macOS blocks it the first time: open it once, then click **Open Anyway** in
*System Settings → Privacy & Security*. }Flickbar then asks for **Accessibility** access, which macOS requires for
apps that arrange windows. If gestures stop working after an update, remove Flickbar from the Accessibility list
with **−** and add it again.

Requires macOS 14 Sonoma or later and a trackpad. Universal (Apple silicon and Intel).

SHA-256 of the zip: \`$SHA\`
EOF
} > build/release/notes.md

git push -q
git tag "v$VERSION"
git push -q origin "v$VERSION"
gh release create "v$VERSION" "$ZIP" --title "Flickbar $VERSION" --notes-file build/release/notes.md

if [ -n "$TAPPED" ]; then
    TAP=build/homebrew-tap
    [ -d "$TAP/.git" ] || gh repo clone flickbar/homebrew-tap "$TAP" -- -q
    git -C "$TAP" pull -q
    sed -i '' "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$TAP/Casks/flickbar.rb"
    git -C "$TAP" commit -qam "Flickbar $VERSION"
    git -C "$TAP" push -q
else
    echo "warning: flickbar/homebrew-tap doesn't exist yet; cask not updated" >&2
fi
echo "Released $VERSION"
