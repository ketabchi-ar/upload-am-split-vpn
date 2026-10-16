#!/usr/bin/env bash
set -euo pipefail

echo "============================================="
echo " Upload.am Rule-Based Split VPN Installer    "
echo "============================================="

# Check Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo "Error: Homebrew is required. Install from https://brew.sh"
    exit 1
fi

# Check OpenVPN
if ! command -v openvpn >/dev/null 2>&1; then
    echo "Installing openvpn via Homebrew..."
    brew install openvpn
fi

# Build App
cd app
./build.sh
cd ..

# Deploy to ~/Applications
TARGET_APP="$HOME/Applications/UploadAmVPN.app"
rm -rf "$TARGET_APP"
mkdir -p "$HOME/Applications"
cp -r "app/build/UploadAmVPN.app" "$TARGET_APP"

echo "Installation successful!"
echo "App deployed to: $TARGET_APP"
echo "To launch: open \"$TARGET_APP\""
