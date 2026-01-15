#!/bin/bash
# Seek to position on the currently active player

POSITION="$1"
PLAYER=$(eww get media | jq -r '.player // empty')

if [[ -n "$PLAYER" && -n "$POSITION" ]]; then
    playerctl -p "$PLAYER" position "$POSITION"
fi
