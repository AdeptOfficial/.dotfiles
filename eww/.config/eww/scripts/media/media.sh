#!/bin/bash
# Media info via playerctl

PLAYERS=$(playerctl -l 2>/dev/null)

if [[ -z "$PLAYERS" ]]; then
    echo '{"status": "stopped", "title": "", "artist": "", "album": "", "art": ""}'
    exit 0
fi

# Find actively playing player, or use first available
ACTIVE_PLAYER=""
for player in $PLAYERS; do
    status=$(playerctl -p "$player" status 2>/dev/null)
    if [[ "$status" == "Playing" ]]; then
        ACTIVE_PLAYER="$player"
        break
    fi
done
[[ -z "$ACTIVE_PLAYER" ]] && ACTIVE_PLAYER=$(echo "$PLAYERS" | head -1)

STATUS=$(playerctl -p "$ACTIVE_PLAYER" status 2>/dev/null || echo "stopped")
TITLE=$(playerctl -p "$ACTIVE_PLAYER" metadata title 2>/dev/null)
ARTIST=$(playerctl -p "$ACTIVE_PLAYER" metadata artist 2>/dev/null)
ALBUM=$(playerctl -p "$ACTIVE_PLAYER" metadata album 2>/dev/null)
ART=$(playerctl -p "$ACTIVE_PLAYER" metadata mpris:artUrl 2>/dev/null)

jq -n --arg status "$STATUS" --arg title "$TITLE" --arg artist "$ARTIST" \
      --arg album "$ALBUM" --arg art "$ART" \
      '{status: $status, title: $title, artist: $artist, album: $album, art: $art}'
