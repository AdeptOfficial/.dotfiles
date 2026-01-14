#!/bin/bash
# Extract colors from current theme's waybar.css

WAYBAR_CSS="$HOME/.config/themes/current/waybar.css"

if [[ -f "$WAYBAR_CSS" ]]; then
    FG=$(grep "@define-color foreground" "$WAYBAR_CSS" | sed 's/.*#/#/' | sed 's/;.*//')
    BG=$(grep "@define-color background" "$WAYBAR_CSS" | sed 's/.*#/#/' | sed 's/;.*//')
else
    FG="#F0F8FF"
    BG="#0A1428"
fi

echo "{\"foreground\": \"$FG\", \"background\": \"$BG\"}"
