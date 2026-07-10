#!/usr/bin/env bash

# Kill any existing quickshell processes and scripts
killall quickshell 2>/dev/null
pkill -f "quickshell/scripts/" 2>/dev/null

# Kill existing notification daemons to allow our custom daemon to claim DBus
killall mako dunst swaync fnott shelly-notifications 2>/dev/null

# Wait a moment for processes to exit
sleep 1

# Start quickshell
env QT_QPA_PLATFORMTHEME=gtk3 nohup quickshell >/tmp/quickshell.log 2>&1 &
disown
