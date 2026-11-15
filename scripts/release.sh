#!/usr/bin/env bash
# Publishes a new version: tags, builds the DMG, creates the GitHub release and bumps the Homebrew cask.
# Usage: scripts/release.sh 1.0.1   (optionally NOTES=notes.md for the release text)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version>}"
REPO="OfficialBishal/nepali-patro"
TAP_REPO="OfficialBishal/homebrew-tap"

[ -z "$(git status --porcelain)" ] || { echo "Working tree is not clean"; exit 1; }
swift run -c release PatroChecks

echo "$VERSION" > VERSION
# Refresh the subscribable festival feeds (previous, current and next two BS years).
YEAR="$(swift run -c release patro events --en | head -1 | cut -d/ -f1)"
swift run -c release patro ics "$((YEAR - 1))" 4 --en > calendar/nepali-festivals.ics
swift run -c release patro ics "$((YEAR - 1))" 4 > calendar/nepali-festivals-ne.ics
git add VERSION calendar
git commit -m "Release $VERSION"
git tag "v$VERSION"
git push origin main "v$VERSION"

./scripts/build.sh
DMG="dist/NepaliPatro-$VERSION.dmg"
SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
if [ -n "${NOTES:-}" ]; then
  gh release create "v$VERSION" "$DMG" --repo "$REPO" --title "Nepali Patro $VERSION" --notes-file "$NOTES"
else
  gh release create "v$VERSION" "$DMG" --repo "$REPO" --title "Nepali Patro $VERSION" --generate-notes
fi

TAP="$(mktemp -d)"
gh repo clone "$TAP_REPO" "$TAP" -- -q
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$TAP/Casks/nepali-patro.rb"
git -C "$TAP" commit -am "nepali-patro $VERSION"
git -C "$TAP" push -q
rm -rf "$TAP"

echo "Released $VERSION. Users update with: brew upgrade --cask nepali-patro"
