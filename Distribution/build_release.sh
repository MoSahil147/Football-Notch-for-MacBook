#!/bin/bash
# Distribution/build_release.sh
# Builds and zips FootballNotch.app for a GitHub release.
#
# Free path (default, no Apple Developer account needed): plain ad-hoc
# signing, the same thing Xcode does automatically for any local build.
# Gatekeeper will still flag an ad-hoc-signed app the first time someone
# opens it directly, which is why Distribution/Casks/football-notch.rb
# strips the quarantine flag automatically as part of `brew install --cask`,
# before the user ever opens it themselves.
#
# Paid path (optional): set DEVELOPER_ID_APPLICATION to properly sign and
# notarise with a real Apple Developer ID, if you ever want it. Not required.
set -euo pipefail

PROJECT="FootballNotch/FootballNotch.xcodeproj"
SCHEME="FootballNotch"
ZIP_PATH="build/FootballNotch.zip"

if [ -z "${DEVELOPER_ID_APPLICATION:-}" ]; then
  echo "No DEVELOPER_ID_APPLICATION set: building the free way (ad-hoc signed, no Apple Developer account needed)."

  DERIVED_DATA="build/DerivedData"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath "$DERIVED_DATA" build

  APP_PATH="$DERIVED_DATA/Build/Products/Release/FootballNotch.app"
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

  echo "Built $ZIP_PATH (ad-hoc signed)."
  echo "Next: upload it as a GitHub release asset, then update sha256 in your Cask formula:"
  echo "  shasum -a 256 $ZIP_PATH"
  exit 0
fi

# --- Paid path: proper Developer ID signing + notarisation ---
ARCHIVE_PATH="build/FootballNotch.xcarchive"
EXPORT_PATH="build/export"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  archive -archivePath "$ARCHIVE_PATH"

if [ ! -f "Distribution/ExportOptions.plist" ]; then
  echo "Distribution/ExportOptions.plist not found."
  echo "Copy Distribution/ExportOptions.plist.template to Distribution/ExportOptions.plist"
  echo "and fill in your own Team ID first."
  exit 1
fi

xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" -exportOptionsPlist Distribution/ExportOptions.plist

ditto -c -k --keepParent "$EXPORT_PATH/FootballNotch.app" "$ZIP_PATH"

if [ -z "${NOTARY_PROFILE:-}" ]; then
  echo "Signed but NOT notarised: NOTARY_PROFILE not set."
  echo "Gatekeeper will still block this build for other users. Run:"
  echo "  xcrun notarytool store-credentials <profile-name> --apple-id <you@example.com> --team-id <TEAMID> --password <app-specific-password>"
  echo "then re-run this script with NOTARY_PROFILE=<profile-name>."
  exit 0
fi

echo "Submitting for notarisation (this can take a few minutes)..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling notarisation ticket to the .app..."
xcrun stapler staple "$EXPORT_PATH/FootballNotch.app"

# Re-zip after stapling, since the ticket is attached to the .app itself.
ditto -c -k --keepParent "$EXPORT_PATH/FootballNotch.app" "$ZIP_PATH"

echo "Built and notarised $ZIP_PATH"
echo "Next: upload it as a GitHub release asset, then update sha256 in your Cask formula:"
echo "  shasum -a 256 $ZIP_PATH"
