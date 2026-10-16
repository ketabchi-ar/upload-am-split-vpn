#!/usr/bin/env bash
set -euo pipefail

APP_NAME="UploadAmVPN"
BUNDLE_DIR="build/${APP_NAME}.app"

echo "Building ${APP_NAME}.app..."
rm -rf build
mkdir -p "${BUNDLE_DIR}/Contents/"{MacOS,Resources}

cp -r Resources/* "${BUNDLE_DIR}/Contents/Resources/"

cat << 'PLIST' > "${BUNDLE_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>UploadAmVPN</string>
    <key>CFBundleIdentifier</key>
    <string>com.ardalan.uploadamvpn</string>
    <key>CFBundleName</key>
    <string>Upload.am VPN</string>
    <key>CFBundleDisplayName</key>
    <string>Upload.am VPN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

swiftc -O main.swift -o "${BUNDLE_DIR}/Contents/MacOS/${APP_NAME}"

echo "Build complete: ${BUNDLE_DIR}"
