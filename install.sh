#!/bin/bash

# Define paths
INSTALL_DIR="$HOME/WiFiAutoLogin"
SCRIPT_NAME="wifi_auto_login_realtime.sh"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
PLIST_NAME="com.wifi.auto_login.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"
CREDENTIALS_FILE="$INSTALL_DIR/credentials.txt"

# Create directories if they don’t exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

# Download or copy the script (Modify this if it's stored elsewhere)
cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash
# wifi_auto_login_realtime.sh
# Polls for connectivity loss and auto-rotates credentials to log in using the campnet portal.

CREDENTIALS_FILE="$HOME/WiFiAutoLogin/credentials.txt"
CRED_INDEX_FILE="$HOME/.credential_index"
LOGIN_URL="https://10.1.0.10:8090/login.xml"

if [ ! -f "$CRED_INDEX_FILE" ]; then
    echo 0 > "$CRED_INDEX_FILE"
fi

log() {
    echo "$(date): $1" >> ~/WiFiAutoLogin/wifi_auto_login_log.txt
}

notify_user() {
    osascript -e "display notification \"$1\" with title \"WiFi Auto-Login\""
}

get_next_credentials() {
    index=$(cat "$CRED_INDEX_FILE")
    credentials=$(sed -n "$((index + 1))p" "$CREDENTIALS_FILE")
    if [ -z "$credentials" ]; then
         index=0
         credentials=$(sed -n "1p" "$CREDENTIALS_FILE")
    fi
    total=$(wc -l < "$CREDENTIALS_FILE")
    next=$(( (index + 1) % total ))
    echo $next > "$CRED_INDEX_FILE"
    echo "$credentials"
}

login() {
    creds=$(get_next_credentials)
    username=$(echo "$creds" | cut -d',' -f2)
    password=$(echo "$creds" | cut -d',' -f3)
    a=$(python3 -c 'import time; print(int(time.time()*1000))')

    response=$(curl -k -s -d "mode=191&username=${username}&password=${password}&a=${a}&producttype=0" "$LOGIN_URL")

    if echo "$response" | grep -q "LIVE"; then
        notify_user "Logged in successfully with ID: $username"
    else
        notify_user "Login failed for ID: $username"
        log "Login failed for ID: $username"
    fi
}

is_connected() {
    response=$(curl -s --max-time 10 http://captive.apple.com/hotspot-detect.html)
    if echo "$response" | grep -q "Success"; then
        return 0
    else
        return 1
    fi
}

while true; do
    if ! is_connected; then
         log "Connectivity lost; triggering auto-login..."
         login
         sleep 2
    fi
    sleep 5
done
EOF

# Make script executable
chmod +x "$SCRIPT_PATH"

# Create LaunchAgent plist
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wifi.auto_login</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/wifi_auto_login.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/wifi_auto_login.err</string>
</dict>
</plist>
EOF

# Make sure credentials file exists
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "Name1,username1,password1" > "$CREDENTIALS_FILE"
fi

# Set permissions
chmod 644 "$PLIST_PATH"

# Load LaunchAgent
launchctl load "$PLIST_PATH"

echo "✅ WiFi Auto-Login installed successfully! Script is running in the background."

