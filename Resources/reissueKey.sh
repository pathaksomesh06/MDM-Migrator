#!/bin/bash

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit 1
fi

# Get the actual username (not root)
ACTUAL_USER=$SUDO_USER
if [ -z "$ACTUAL_USER" ]; then
    ACTUAL_USER=$(who | grep console | awk '{print $1}')
fi

# Function to show error message via GUI (run as actual user)
show_error() {
    su "$ACTUAL_USER" -c "osascript -e 'display dialog \"$1\" buttons {\"OK\"} default button \"OK\" with icon stop'"
}

# Function to show success message with the new recovery key via GUI
show_success() {
    su "$ACTUAL_USER" -c "osascript -e 'display dialog \"Your new FileVault recovery key is:\n\n$1\n\nPlease store this key in a safe place.\" buttons {\"OK\"} default button \"OK\" with icon caution'"
}

# Function to get user's password via GUI
get_user_password() {
    su "$ACTUAL_USER" -c "osascript -e 'tell application \"System Events\"
        display dialog \"Please enter your user account password to rotate FileVault key:\" with hidden answer default answer \"\" buttons {\"Cancel\", \"OK\"} default button \"OK\" with icon caution
        if button returned of result is \"OK\" then
            return text returned of result
        else
            return \"CANCELED\"
        end if
    end tell'"
}

# Check if FileVault is enabled
if ! fdesetup isactive; then
    show_error "FileVault is not enabled on this system."
    exit 1
fi

# Get user's password
USER_PASSWORD=$(get_user_password)

if [ "$USER_PASSWORD" = "CANCELED" ]; then
    show_error "Operation canceled by user."
    exit 1
fi

# Create a temporary plist file for FileVault authentication
PLIST_FILE=$(mktemp)
chmod 600 "$PLIST_FILE"

cat << EOF > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Username</key>
    <string>$ACTUAL_USER</string>
    <key>Password</key>
    <string>$USER_PASSWORD</string>
</dict>
</plist>
EOF

# Execute fdesetup directly (no need for osascript since we're already root)
OUTPUT=$(fdesetup changerecovery -personal -inputplist < "$PLIST_FILE" 2>&1)
RESULT=$?

# Clean up the plist file immediately
rm -f "$PLIST_FILE"

if [ $RESULT -ne 0 ]; then
    show_error "Failed to rotate FileVault key: $OUTPUT"
    exit 1
fi

# Check if we got a valid recovery key
if [ -z "$OUTPUT" ] || [[ "$OUTPUT" == *"Error"* ]]; then
    show_error "Failed to generate new recovery key: $OUTPUT"
    exit 1
fi

# Show the new recovery key in a GUI dialog
show_success "$OUTPUT"

echo "FileVault key rotation completed successfully."
