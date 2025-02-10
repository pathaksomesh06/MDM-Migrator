#!/bin/bash

# Get the app's directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_BINARY="$DIR/MDM Migrator"  # This should match your binary name exactly

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    # Not root, request privileges and launch
    exec osascript -e "do shell script \"'$APP_BINARY'\" with administrator privileges"
fi

# Already root, execute directly
exec "$APP_BINARY"
