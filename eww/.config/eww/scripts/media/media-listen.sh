#!/bin/bash
# Media info via playerctl --follow (deflisten version)
# Outputs JSON whenever media state changes

CACHE_DIR="$HOME/.cache/eww/album-art"
mkdir -p "$CACHE_DIR"

# Debug logging - helps diagnose eww freezes
DEBUG_LOG="$HOME/.cache/eww/debug/media-listen.log"
mkdir -p "$(dirname "$DEBUG_LOG")"
log_debug() { echo "[$(date '+%H:%M:%S')] $1" >> "$DEBUG_LOG"; }
log_debug "=== media-listen.sh started (PID $$) ==="

# Function to get current media state
get_media_state() {
    local PLAYERS=$(playerctl -l 2>/dev/null)

    if [[ -z "$PLAYERS" ]]; then
        echo '{"status":"stopped","title":"","artist":"","album":"","art":"","position":0,"duration":0,"position_fmt":"0:00","duration_fmt":"0:00","player":"","players":[],"volume":50,"muted":false}'
        return
    fi

    # Convert players to JSON array
    local PLAYERS_JSON=$(echo "$PLAYERS" | jq -R . | jq -sc .)

    # Get selected player from eww or auto-detect
    local SELECTED=$(eww get selected-player 2>/dev/null)

    # Find active player
    local ACTIVE_PLAYER=""
    if [[ -n "$SELECTED" ]] && echo "$PLAYERS" | grep -q "^$SELECTED$"; then
        ACTIVE_PLAYER="$SELECTED"
    else
        while IFS= read -r player; do
            local status=$(playerctl -p "$player" status 2>/dev/null)
            if [[ "$status" == "Playing" ]]; then
                ACTIVE_PLAYER="$player"
                break
            fi
        done <<< "$PLAYERS"
        [[ -z "$ACTIVE_PLAYER" ]] && ACTIVE_PLAYER=$(echo "$PLAYERS" | head -1)
    fi

    # Get media info
    local STATUS=$(playerctl -p "$ACTIVE_PLAYER" status 2>/dev/null || echo "stopped")
    local TITLE=$(playerctl -p "$ACTIVE_PLAYER" metadata title 2>/dev/null)
    local ARTIST=$(playerctl -p "$ACTIVE_PLAYER" metadata artist 2>/dev/null)
    local ALBUM=$(playerctl -p "$ACTIVE_PLAYER" metadata album 2>/dev/null)
    local ART_URL=$(playerctl -p "$ACTIVE_PLAYER" metadata mpris:artUrl 2>/dev/null)

    # Get position and duration
    local POSITION=$(playerctl -p "$ACTIVE_PLAYER" position 2>/dev/null || echo "0")
    POSITION=${POSITION%.*}
    local DURATION_US=$(playerctl -p "$ACTIVE_PLAYER" metadata mpris:length 2>/dev/null || echo "0")
    local DURATION=$((DURATION_US / 1000000))

    # Format time (MM:SS)
    local POSITION_FMT=$(printf "%d:%02d" $((POSITION / 60)) $((POSITION % 60)))
    local DURATION_FMT=$(printf "%d:%02d" $((DURATION / 60)) $((DURATION % 60)))

    # Handle album art
    local ART_PATH=""
    if [[ "$ART_URL" == file://* ]]; then
        ART_PATH="${ART_URL#file://}"
    elif [[ "$ART_URL" == http* ]]; then
        local HASH=$(echo "$ART_URL" | md5sum | cut -d' ' -f1)
        ART_PATH="$CACHE_DIR/$HASH.png"
        [[ ! -f "$ART_PATH" ]] && curl -s -o "$ART_PATH" "$ART_URL" 2>/dev/null &
    fi
    [[ ! -f "$ART_PATH" ]] && ART_PATH=""

    # Get system volume
    local VOLUME_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    local VOLUME=$(echo "$VOLUME_RAW" | awk '{print int($2 * 100)}')
    local MUTED=$(echo "$VOLUME_RAW" | grep -q "MUTED" && echo "true" || echo "false")
    [[ -z "$VOLUME" ]] && VOLUME=0

    # Escape strings for JSON
    TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    ARTIST=$(echo "$ARTIST" | sed 's/\\/\\\\/g; s/"/\\"/g')
    ALBUM=$(echo "$ALBUM" | sed 's/\\/\\\\/g; s/"/\\"/g')

    echo "{\"status\":\"$STATUS\",\"title\":\"$TITLE\",\"artist\":\"$ARTIST\",\"album\":\"$ALBUM\",\"art\":\"$ART_PATH\",\"position\":$POSITION,\"duration\":$DURATION,\"position_fmt\":\"$POSITION_FMT\",\"duration_fmt\":\"$DURATION_FMT\",\"player\":\"$ACTIVE_PLAYER\",\"players\":$PLAYERS_JSON,\"volume\":$VOLUME,\"muted\":$MUTED}"
}

# Output initial state
log_debug "Outputting initial state"
get_media_state

# Follow all players for any changes and re-output state
# Using -a to follow all players, -F for follow mode
log_debug "Starting playerctl follow loop"
playerctl -a -F metadata --format '{{status}}' 2>/dev/null | while read -r _; do
    log_debug "playerctl event received"
    get_media_state
done &

# Also update on volume changes via pactl subscribe
log_debug "Starting pactl subscribe loop"
pactl subscribe 2>/dev/null | grep --line-buffered "sink" | while read -r _; do
    log_debug "pactl sink event received"
    get_media_state
done &

# Update position every second (for progress bar)
log_debug "Starting main position update loop"
heartbeat_counter=0
while true; do
    sleep 1
    ((heartbeat_counter++))
    # Log heartbeat every 30 seconds to avoid log spam
    ((heartbeat_counter % 30 == 0)) && log_debug "heartbeat (30s) - still running"
    get_media_state
done
