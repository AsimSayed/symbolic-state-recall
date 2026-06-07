#!/usr/bin/env bash
# One-command local release. No CI, no PAT — uses your existing `gh` auth.
#
#   scripts/release.sh 1.0.1
#
# Builds the signed DMG, creates the GitHub Release with it attached, then
# updates the Homebrew cask in AsimSayed/homebrew-tap. After this runs,
# `brew install --cask asimsayed/tap/symbolic-state-recall` serves the new build.
set -euo pipefail

VERSION="${1:?usage: release.sh <version>   e.g. release.sh 1.0.1}"
TAG="v${VERSION}"
APP_REPO="AsimSayed/symbolic-state-recall"
TAP_REPO="AsimSayed/homebrew-tap"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v gh >/dev/null || { echo "error: gh CLI required" >&2; exit 1; }

# 1. Build the signed DMG.
bash scripts/package-dmg.sh "$VERSION"
DMG="$ROOT/dist/symbolicStateRecall-${VERSION}.dmg"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"

# 2. Tag + publish the GitHub Release.
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag "$TAG"
  git push origin "$TAG"
fi
gh release create "$TAG" "$DMG" \
  --repo "$APP_REPO" \
  --title "$TAG" \
  --generate-notes

# 3. Bump the cask in the tap repo.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
gh repo clone "$TAP_REPO" "$TMP/tap" -- --depth 1
CASK="$TMP/tap/Casks/symbolic-state-recall.rb"
/usr/bin/sed -i '' -E "s/version \".*\"/version \"${VERSION}\"/" "$CASK"
/usr/bin/sed -i '' -E "s/sha256 \".*\"/sha256 \"${SHA}\"/" "$CASK"
git -C "$TMP/tap" add Casks/symbolic-state-recall.rb
git -C "$TMP/tap" commit -m "symbolic-state-recall ${VERSION}"
git -C "$TMP/tap" push

echo
echo "Released $TAG. Users can now run:"
echo "  brew install --cask asimsayed/tap/symbolic-state-recall"
