#!/bin/bash
# One bounded producer: complete JSON records, no concurrent event-loop writers.
CACHE_DIR="$HOME/.cache/eww/album-art"
mkdir -p "$CACHE_DIR"
export CACHE_DIR

get_media_state() {
    local raw volume muted players selected player status title artist album art_url
    local position duration_us duration art_path="" tmp hash
    raw=$(timeout 1 wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    volume=$(awk '{print int($2 * 100 + 0.5)}' <<< "$raw")
    [[ $volume =~ ^[0-9]+$ ]] || volume=0
    muted=false
    [[ $raw == *MUTED* ]] && muted=true
    players=$(timeout 1 playerctl -l 2>/dev/null)
    selected=$(timeout 1 eww get selected-player 2>/dev/null)
    player=""
    if [[ -n $selected ]] && grep -Fxq -- "$selected" <<< "$players"; then
        player=$selected
    elif [[ -n $players ]]; then
        player=$(head -1 <<< "$players")
        while IFS= read -r candidate; do
            if [[ $(timeout 0.5 playerctl -p "$candidate" status 2>/dev/null) == Playing ]]; then
                player=$candidate
                break
            fi
        done <<< "$players"
    fi
    status=stopped; title=""; artist=""; album=""; position=0; duration_us=0
    if [[ -n $player ]]; then
        status=$(timeout 1 playerctl -p "$player" status 2>/dev/null)
        title=$(timeout 1 playerctl -p "$player" metadata title 2>/dev/null)
        artist=$(timeout 1 playerctl -p "$player" metadata artist 2>/dev/null)
        album=$(timeout 1 playerctl -p "$player" metadata album 2>/dev/null)
        position=$(timeout 1 playerctl -p "$player" position 2>/dev/null)
        duration_us=$(timeout 1 playerctl -p "$player" metadata mpris:length 2>/dev/null)
        art_url=$(timeout 1 playerctl -p "$player" metadata mpris:artUrl 2>/dev/null)
        if [[ $art_url == file://* ]]; then
            art_path=${art_url#file://}
        elif [[ $art_url == https://* || $art_url == http://* ]]; then
            hash=$(printf %s "$art_url" | sha256sum | cut -d' ' -f1)
            art_path="$CACHE_DIR/$hash.png"
            if [[ ! -s $art_path ]]; then
                tmp=$(mktemp "$CACHE_DIR/.download.XXXXXX")
                if curl -fsSL --connect-timeout 1 --max-time 2 --max-filesize 5242880 -o "$tmp" "$art_url" && [[ -s $tmp ]]; then
                    mv "$tmp" "$art_path"
                else
                    rm -f "$tmp"
                fi
            fi
        fi
    fi
    [[ -s $art_path ]] || art_path=""
    position=${position%%.*}
    [[ $position =~ ^[0-9]{1,12}$ ]] || position=0
    [[ $duration_us =~ ^[0-9]{1,16}$ ]] || duration_us=0
    position=$((10#$position)); duration=$((10#$duration_us / 1000000))
    jq -cn --arg status "${status:-stopped}" --arg title "$title" --arg artist "$artist" \
      --arg album "$album" --arg art "$art_path" --arg player "$player" \
      --arg players "$players" --argjson position "$position" --argjson duration "$duration" \
      --arg position_fmt "$(printf '%d:%02d' $((position / 60)) $((position % 60)))" \
      --arg duration_fmt "$(printf '%d:%02d' $((duration / 60)) $((duration % 60)))" \
      --argjson volume "$volume" --argjson muted "$muted" \
      '{status:$status,title:$title,artist:$artist,album:$album,art:$art,player:$player,
        players:($players|split("\n")|map(select(length>0))),position:$position,duration:$duration,
        position_fmt:$position_fmt,duration_fmt:$duration_fmt,volume:$volume,muted:$muted}'
}
export -f get_media_state
failed=false
while true; do
    # No partial record reaches EWW on timeout; retain the previous good state.
    if state=$(timeout --kill-after=1 6 bash -c get_media_state) && jq -e . >/dev/null <<< "$state"; then
        if $failed; then printf '[media] snapshot updates recovered\n' >&2; fi
        failed=false
        printf '%s\n' "$state" || exit 0
    else
        if ! $failed; then printf '[media] snapshot failed or timed out; retaining previous state and retrying\n' >&2; fi
        failed=true
    fi
    sleep 1
done
