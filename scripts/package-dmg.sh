#!/usr/bin/env bash
# Build a Release symbolicStateRecall.app, ad-hoc sign it, and wrap it in a
# drag-to-Applications DMG. Prints the artifact path and its sha256.
#
# Usage: scripts/package-dmg.sh <version>
#   e.g. scripts/package-dmg.sh 1.0.0
#
# Output: dist/symbolicStateRecall-<version>.dmg  (+ .sha256 next to it)
# Used by both local releases and .github/workflows/release.yml.
set -euo pipefail

VERSION="${1:?usage: package-dmg.sh <version>}"
SCHEME="symbolicStateRecall"
PROJECT="symbolicStateRecall.xcodeproj"
VOLNAME="Symbolic State Recall"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$(mktemp -d)"
DIST="$ROOT/dist"
DMG="$DIST/symbolicStateRecall-${VERSION}.dmg"
mkdir -p "$DIST"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "==> Building $SCHEME (Release, ad-hoc signed)…"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/dd" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

APP="$BUILD_DIR/dd/Build/Products/Release/${SCHEME}.app"
[ -d "$APP" ] || { echo "error: built app not found at $APP" >&2; exit 1; }

# Ad-hoc sign the bundle so the binary has a stable code signature.
# (Free signing — not Developer ID. Homebrew strips quarantine on install,
#  so the app launches without a Gatekeeper prompt.)
echo "==> Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "==> Building DMG…"
STAGING="$BUILD_DIR/staging"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG" >/dev/null

SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "$SHA  $(basename "$DMG")" > "$DMG.sha256"

echo
echo "DMG:    $DMG"
echo "SHA256: $SHA"

# Expose outputs to GitHub Actions when running in CI.
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "dmg=$DMG"
    echo "sha256=$SHA"
  } >> "$GITHUB_OUTPUT"
fi
