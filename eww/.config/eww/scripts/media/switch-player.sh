#!/bin/bash
set -euo pipefail
PLAYER="${1:?Missing player}"
timeout 2 eww update selected-player="$PLAYER"
# Run outside EWW's poll command: the reader itself needs EWW IPC.
STATE=$(timeout 5 python3 "$(dirname "$0")/audio-volume.py")
# Discard a result if another click has superseded it.
[[ $(timeout 2 eww get selected-player) == "$PLAYER" ]] || exit 0
timeout 2 eww update player-audio="$STATE"
