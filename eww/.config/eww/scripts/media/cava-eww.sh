#!/bin/bash
# Cava audio visualizer for EWW
# Outputs Unicode bar characters based on audio levels

# Debug logging - helps diagnose eww freezes
DEBUG_LOG="$HOME/.cache/eww/debug/cava-eww.log"
mkdir -p "$(dirname "$DEBUG_LOG")"
log_debug() { echo "[$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"; }
log_debug "=== cava-eww.sh started (PID $$) ==="

# Heartbeat logger in background
(
  while true; do
    sleep 30
    log_debug "heartbeat (30s) - cava pipeline running"
  done
) &
HEARTBEAT_PID=$!
trap "kill $HEARTBEAT_PID 2>/dev/null" EXIT

cava -p <(cat <<EOF
[general]
framerate = 30
bars = 52
sensitivity = 120

[input]
method = pulse

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF
) | sed -u 's/;//g;s/0/▁/g;s/1/▂/g;s/2/▃/g;s/3/▄/g;s/4/▅/g;s/5/▆/g;s/6/▇/g;s/7/█/g'
