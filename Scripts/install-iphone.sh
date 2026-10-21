#!/bin/bash
# Builds the iPhone app (VocTrain) in Release, signs it with the ad-hoc distribution
# certificate bought from iApps (Furman in Telegram, 20.10.2026) and installs it on the
# iPhone over the CoreDevice connection Xcode already has.
#
# The profile allows exactly one App ID, so the bundle id comes from the profile, not
# from the project: a build with the project's id would install and refuse to launch.
# Identity and profile live outside the repository in $IOS_SIGNING_DIR:
#   iapps.mobileprovision   the profile from the chat
#   signing.keychain-db     a keychain of its own holding only that identity
#   keychain.pass           its password
# How to recreate them from the chat files: HANDOFF.md §Подпись iPhone.
#
# Version as on the Mac: CFBundleShortVersionString from VERSION, CFBundleVersion the
# short commit hash, "+" if the tree is dirty.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIGN_DIR="${IOS_SIGNING_DIR:-$HOME/.local/share/ios-signing/iapps-2026-10-20}"
PROFILE="$SIGN_DIR/iapps.mobileprovision"
KC="$SIGN_DIR/signing.keychain-db"
DEVICE="${IPHONE_UDID:-00008110-000411010C68401E}"
PB=/usr/libexec/PlistBuddy

OUT="$ROOT/build/iphone"
rm -rf "$OUT"
mkdir -p "$OUT"
security cms -D -i "$PROFILE" > "$OUT/profile.plist"
APP_ID="$($PB -c 'Print :Entitlements:application-identifier' "$OUT/profile.plist")"
TEAM="${APP_ID%%.*}"
BUNDLE_ID="${APP_ID#*.}"
echo "profile: $($PB -c 'Print :Name' "$OUT/profile.plist"), app id $APP_ID, expires $($PB -c 'Print :ExpirationDate' "$OUT/profile.plist")"
$PB -c 'Print :ProvisionedDevices' "$OUT/profile.plist" | grep -q "$DEVICE" ||
  { echo "the profile does not list device $DEVICE" >&2; exit 1; }

SHORT_VERSION="$(tr -d '[:space:]' < VERSION)"
GIT_HASH="$(git rev-parse --short HEAD)"
[ -z "$(git status --porcelain)" ] || GIT_HASH="${GIT_HASH}+"
echo "building VocTrain $SHORT_VERSION ($GIT_HASH) as $BUNDLE_ID"

xcodebuild build -quiet -project MacVocTrainNg.xcodeproj -scheme VocTrain \
  -destination 'generic/platform=iOS' -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  MARKETING_VERSION="$SHORT_VERSION" CURRENT_PROJECT_VERSION="$GIT_HASH"

APP="$OUT/VocTrain.app"
cp -R build/DerivedData/Build/Products/Release-iphoneos/VocTrain.app "$APP"
cp "$PROFILE" "$APP/embedded.mobileprovision"

for pair in "CFBundleIdentifier=$BUNDLE_ID" "CFBundleShortVersionString=$SHORT_VERSION" "CFBundleVersion=$GIT_HASH"; do
  got="$($PB -c "Print :${pair%%=*}" "$APP/Info.plist")"
  [ "$got" = "${pair#*=}" ] || { echo "${pair%%=*} did not reach the bundle: $got" >&2; exit 1; }
done

# Only what the app uses. The profile grants far more (HealthKit, NFC, VPN, …);
# signing with an entitlement the profile lacks makes installd refuse the app.
cat > "$OUT/entitlements.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>application-identifier</key><string>$APP_ID</string>
	<key>com.apple.developer.team-identifier</key><string>$TEAM</string>
	<key>get-task-allow</key><false/>
	<key>keychain-access-groups</key><array><string>$APP_ID</string></array>
</dict>
</plist>
EOF

security unlock-keychain -p "$(cat "$SIGN_DIR/keychain.pass")" "$KC"
IDENTITY="$(security find-identity -v -p codesigning "$KC" | awk 'NR==1 && $2 ~ /^[0-9A-F]{40}$/ {print $2}')"
[ -n "$IDENTITY" ] || { echo "no signing identity in $KC" >&2; exit 1; }
codesign --force --sign "$IDENTITY" --keychain "$KC" --timestamp=none \
  --entitlements "$OUT/entitlements.plist" --generate-entitlement-der "$APP"
codesign --verify --strict "$APP"
security lock-keychain "$KC"

xcrun devicectl device install app --device "$DEVICE" "$APP"
echo "installed VocTrain $SHORT_VERSION ($GIT_HASH) on $DEVICE"
