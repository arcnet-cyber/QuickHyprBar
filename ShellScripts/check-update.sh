#!/bin/bash

# Configuration options
TERMINAL_EXEC="kitty -e"
SAVE_PATH="$HOME/.local/bin/check_updates.sh"

# Safe background update checking via pacman-contrib
UPDATES=$(checkupdates 2>/dev/null | wc -l)

# End execution if the system is completely up-to-date
if [ "$UPDATES" -eq 0 ]; then
    notify-send "System Up To Date"
    exit 0 
fi

# Broadcast the update notification to your Quickshell layout
# --wait holds the execution loop open until an interaction occurs
notify-send "System Updates" \
    "$UPDATES pacman updates are ready.\nRun Update in Terminal to install." \
    --expire-time=0 \
    --wait


