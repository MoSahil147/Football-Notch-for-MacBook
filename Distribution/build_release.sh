#!/bin/bash
# Distribution/build_release.sh
# Builds, archives, and zips FootballNotch.app for a GitHub release.
# Signing/notarization requires a paid Apple Developer ID — run this
# step manually once that's set up; script stops with instructions if missing.
set -euo pipefail

PROJECT="FootballNotch/FootballNotch.xcodeproj"
SCHEME="FootballNotch"
ARCHIVE_PATH="build/FootballNotch.xcarchive"
EXPORT_PATH="build/export"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
  archive -archivePath "$ARCHIVE_PATH"

if [ -z "${DEVELOPER_ID_APPLICATION:-}" ]; then
  echo "DEVELOPER_ID_APPLICATION not set — skipping codesign/notarize."
  echo "Set it to your 'Developer ID Application: ...' identity to sign for distribution."
  exit 0
fi

xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" -exportOptionsPlist Distribution/ExportOptions.plist

ditto -c -k --keepParent "$EXPORT_PATH/FootballNotch.app" "build/FootballNotch.zip"
echo "Built build/FootballNotch.zip — upload as a GitHub release asset, then update the Cask sha256."
