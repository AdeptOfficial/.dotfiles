#!/bin/bash
# Media control for the currently active player

ACTION="$1"
PLAYER=$(eww get media | jq -r '.player // empty')

if [[ -n "$PLAYER" && -n "$ACTION" ]]; then
    playerctl -p "$PLAYER" "$ACTION"
fi
