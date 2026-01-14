#!/bin/bash
# System info for dashboard - dynamic detection

# Distro (from /etc/os-release)
DISTRO=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)

# WM/Compositor (detect running)
if [[ "$XDG_CURRENT_DESKTOP" ]]; then
    WM="$XDG_CURRENT_DESKTOP"
elif pgrep -x "Hyprland" > /dev/null; then
    WM="Hyprland"
elif pgrep -x "sway" > /dev/null; then
    WM="Sway"
elif [[ "$WAYLAND_DISPLAY" ]]; then
    WM="Wayland"
else
    WM="Unknown"
fi

# Uptime (formatted)
UPTIME=$(uptime -p | sed 's/up //')

# Output JSON for eww
echo "{\"distro\": \"$DISTRO\", \"wm\": \"$WM\", \"uptime\": \"$UPTIME\"}"
