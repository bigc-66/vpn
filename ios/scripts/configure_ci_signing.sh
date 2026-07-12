#!/bin/bash
# CI Manual Code Signing Script for iOS
# Usage: bash ios/scripts/configure_ci_signing.sh

set -euo pipefail

# ── Required environment variables ──
: "${TEAM_ID:?Must set TEAM_ID}"
: "${APP_PROFILE_PATH:?Must set APP_PROFILE_PATH}"
: "${EXT_PROFILE_PATH:?Must set EXT_PROFILE_PATH}"
: "${EXPORT_METHOD:?Must set EXPORT_METHOD (app-store or ad-hoc)}"

PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Configuring iOS Code Signing (CI)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Step 1: Decode and install provisioning profiles ──
mkdir -p "$PROFILE_DIR"

APP_PROFILE=$(basename "$APP_PROFILE_PATH")
EXT_PROFILE=$(basename "$EXT_PROFILE_PATH")

if [[ -f "$APP_PROFILE_PATH" ]]; then
  cp "$APP_PROFILE_PATH" "$PROFILE_DIR/$APP_PROFILE"
  echo "[OK] App profile copied"
fi

if [[ -f "$EXT_PROFILE_PATH" ]]; then
  cp "$EXT_PROFILE_PATH" "$PROFILE_DIR/$EXT_PROFILE"
  echo "[OK] Extension profile copied"
fi

# ── Step 2: Extract Profile UUIDs and Names ──
APP_UUID=$(grep -a -A1 'UUID' "$PROFILE_DIR/$APP_PROFILE" | grep '<string>' | sed 's/.*<string>//;s/<\/string>.*//' | head -1)
EXT_UUID=$(grep -a -A1 'UUID' "$PROFILE_DIR/$EXT_PROFILE" | grep '<string>' | sed 's/.*<string>//;s/<\/string>.*//' | head -1)

APP_PROFILE_NAME=$(grep -a -A1 'Name' "$PROFILE_DIR/$APP_PROFILE" | grep '<string>' | sed 's/.*<string>//;s/<\/string>.*//' | head -1)
EXT_PROFILE_NAME=$(grep -a -A1 'Name' "$PROFILE_DIR/$EXT_PROFILE" | grep '<string>' | sed 's/.*<string>//;s/<\/string>.*//' | head -1)

# If empty, fallback to filename
APP_PROFILE_NAME=${APP_PROFILE_NAME:-$APP_PROFILE}
EXT_PROFILE_NAME=${EXT_PROFILE_NAME:-$EXT_PROFILE}

echo "App  Profile: $APP_PROFILE_NAME ($APP_UUID)"
echo "Ext  Profile: $EXT_PROFILE_NAME ($EXT_UUID)"

# Install with correct UUID filenames
if [[ -n "$APP_UUID" ]]; then
  cp "$PROFILE_DIR/$APP_PROFILE" "$PROFILE_DIR/${APP_UUID}.mobileprovision"
  echo "[OK] App profile installed as ${APP_UUID}.mobileprovision"
fi
if [[ -n "$EXT_UUID" ]]; then
  cp "$PROFILE_DIR/$EXT_PROFILE" "$PROFILE_DIR/${EXT_UUID}.mobileprovision"
  echo "[OK] Ext profile installed as ${EXT_UUID}.mobileprovision"
fi

# ── Step 3: Generate ExportOptions.plist ──
EXPORT_PLIST="ios/ExportOptions.plist"

cat > "$EXPORT_PLIST" << PLISTEND
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>${EXPORT_METHOD}</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.netsignory.app</key>
		<string>${APP_PROFILE_NAME}</string>
		<key>com.netsignory.app.VPNTunnel</key>
		<string>${EXT_PROFILE_NAME}</string>
	</dict>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLISTEND

echo "[OK] Generated $EXPORT_PLIST"

# ── Step 4: Configure Runner.xcodeproj signing ──
ruby << 'RUBY'
require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
team_id = ENV['TEAM_ID']

app_profile = ENV['APP_PROFILE_NAME'] || ''
ext_profile = ENV['EXT_PROFILE_NAME'] || ''

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['DEVELOPMENT_TEAM'] = team_id
    config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
    config.build_settings['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = 'Apple Distribution'

    if target.name == 'Runner'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = app_profile
    elsif target.name == 'VPNTunnel'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ext_profile
    end
  end
end

project.save
puts "[OK] Updated project.pbxproj signing settings"
RUBY

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Code Signing Configuration Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
