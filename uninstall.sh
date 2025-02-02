#!/bin/bash

# Define paths
INSTALL_DIR="$HOME/WiFiAutoLogin"
SCRIPT_NAME="wifi_auto_login_realtime.sh"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
PLIST_NAME="com.wifi.auto_login.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"
CREDENTIALS_FILE="$INSTALL_DIR/credentials.txt"

# Unload the LaunchAgent
if launchctl list | grep -q "com.wifi.auto_login"; then
    launchctl unload "$PLIST_PATH"
    echo "✅ LaunchAgent unloaded."
else
    echo "No LaunchAgent found."
fi

# Remove the script, plist, and credentials
rm -rf "$SCRIPT_PATH"
rm -f "$PLIST_PATH"
rm -f "$CREDENTIALS_FILE"

echo "✅ Uninstalled WiFi Auto-Login. All files removed."

