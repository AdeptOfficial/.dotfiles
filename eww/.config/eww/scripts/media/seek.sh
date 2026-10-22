#!/bin/bash
# A fixed 0–100 range avoids GTK clamping the old position to a new duration.
set -euo pipefail
PERCENT="${1:?Missing seek percentage}"
MEDIA=$(timeout 2 eww get media)
SELECTED=$(timeout 2 eww get selected-player)
PLAYER=$(jq -r '.player // empty' <<< "$MEDIA")
[[ -n $PLAYER && ( -z $SELECTED || $SELECTED == "$PLAYER" ) ]] || exit 0
POSITION=$(jq -er --arg percent "$PERCENT" '
  ($percent | tonumber) as $p |
  select($p >= 0 and $p <= 100 and .duration > 0) |
  (.duration * $p / 100) as $target |
  select(($target - .position | fabs) > 1) | $target' <<< "$MEDIA") || exit 0
timeout 2 playerctl -p "$PLAYER" position "$POSITION"
