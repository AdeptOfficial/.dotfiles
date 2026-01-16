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

# Hostname
HOSTNAME=$(hostname)

# Uptime formatted as "Xd Xh Xm"
UPTIME_SECS=$(cut -d. -f1 /proc/uptime)
DAYS=$((UPTIME_SECS / 86400))
HOURS=$(((UPTIME_SECS % 86400) / 3600))
MINS=$(((UPTIME_SECS % 3600) / 60))
if ((DAYS > 0)); then
    UPTIME="${DAYS}d ${HOURS}h ${MINS}m"
elif ((HOURS > 0)); then
    UPTIME="${HOURS}h ${MINS}m"
else
    UPTIME="${MINS}m"
fi

# Output JSON for eww
echo "{\"distro\": \"$DISTRO\", \"wm\": \"$WM\", \"uptime\": \"$UPTIME\", \"hostname\": \"$HOSTNAME\"}"
