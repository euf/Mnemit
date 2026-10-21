#!/bin/bash
# Builds the Mac app in Release, stamps the version, installs it to ~/Applications,
# signs it with euf-sign and tidies the Launch Services registrations. Same shape as
# FicTypeApp/Scripts/build-release.sh; the reasons for each step are written there.
#
#   CFBundleIdentifier          com.euf.mnemit
#   CFBundleShortVersionString  from VERSION
#   CFBundleVersion             short commit hash, "+" if the tree is dirty
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID=com.euf.mnemit
DEST="$HOME/Applications/Mnemit.app"
ENT="$ROOT/MacVocTrainNg/MacVocTrainNg.entitlements"
PB=/usr/libexec/PlistBuddy

SHORT_VERSION="$(tr -d '[:space:]' < VERSION)"
GIT_HASH="$(git rev-parse --short HEAD)"
[ -z "$(git status --porcelain)" ] || GIT_HASH="${GIT_HASH}+"
echo "building Mnemit $SHORT_VERSION ($GIT_HASH)"

xcodebuild build -quiet -project MacVocTrainNg.xcodeproj -scheme MacVocTrainNg \
  -destination 'platform=macOS' -configuration Release \
  -derivedDataPath build/DerivedData \
  MARKETING_VERSION="$SHORT_VERSION" CURRENT_PROJECT_VERSION="$GIT_HASH"

APP="$ROOT/build/DerivedData/Build/Products/Release/Mnemit.app"
for pair in "CFBundleIdentifier=$BUNDLE_ID" "CFBundleShortVersionString=$SHORT_VERSION" "CFBundleVersion=$GIT_HASH"; do
  got="$($PB -c "Print :${pair%%=*}" "$APP/Contents/Info.plist")"
  [ "$got" = "${pair#*=}" ] || { echo "${pair%%=*} did not reach the bundle: $got" >&2; exit 1; }
done

pkill -x Mnemit 2>/dev/null || true
rm -rf "$DEST"
cp -R "$APP" "$DEST"

# Entitlements are passed explicitly: signing without them drops app-sandbox, and the
# app would silently read ~/Library instead of its container.
euf-sign --entitlements "$ENT" "$DEST"
codesign -d --entitlements :- "$DEST" 2>/dev/null | grep -q com.apple.security.app-sandbox ||
  { echo "signing dropped app-sandbox" >&2; exit 1; }

# Every build tree registers itself with Launch Services; two live registrations of
# one bundle id make the system refuse to open its documents. Keep only the install.
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREG" -dump 2>/dev/null |
  sed -n 's|^path: *\(.*/Mnemit\.app\)\( (0x[0-9a-f]*)\)\{0,1\}$|\1|p' | sort -u |
  while IFS= read -r p; do
    [ "$p" = "$DEST" ] || "$LSREG" -u "$p" 2>/dev/null || true
  done
"$LSREG" -f "$DEST" 2>/dev/null || true

codesign --verify "$DEST"
echo "installed Mnemit $SHORT_VERSION ($GIT_HASH) to $DEST"
