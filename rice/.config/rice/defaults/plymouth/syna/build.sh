#!/bin/bash
# Render the Syna Plymouth theme images from the AdepT brand (palette, JetBrains Mono, A emblem).
# Usage: build.sh [outdir]   (default: ./images). Needs ImageMagick 7 and JetBrains Mono.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); out=${1:-$here/images}; mkdir -p "$out"
F=$(fc-match -f '%{file}' 'JetBrains Mono:style=Regular'); FB=$(fc-match -f '%{file}' 'JetBrains Mono:style=Bold')
# AdepT palette (~/git/adeptproductions/branding/README.md)
INK='#eff8fa' FAINT='#7e95a0' LINE='#203039' CARD='#111a21' SIGNAL='#3fd4e6' MAGENTA='#e359c9' MATRIX='#3fe0a8' CRIMSON='#f0597f' SCARF='#dfa35c'
txt() { magick -background none -font "$1" -pointsize "$2" -fill "$3" label:"$4" PNG32:"$5"; }  # font size color text out

magick "$here/src/emblem-a.png" -trim +repage -resize 180x180 PNG32:"$out/emblem.png"
txt "$FB" 32 "$MAGENTA" '// syna'            "$out/title.png"
txt "$FB" 32 "$MAGENTA" '// syna going dark'  "$out/title-dark.png"
txt "$F"  22 "$FAINT"   'waking syna'         "$out/status-1.png"
txt "$F"  22 "$FAINT"   'loading shards'      "$out/status-2.png"
txt "$F"  22 "$FAINT"   'mounting relays'     "$out/status-3.png"
txt "$F"  22 "$FAINT"   'see you, operator'   "$out/status-dark.png"
# prompt: adept (cyan, AdepT) @ (faint) syna (magenta, Syna) :~$ unlock (faint), one shared baseline
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
txt "$F" 26 "$SIGNAL" 'adept' "$t/1.png"; txt "$F" 26 "$FAINT" '@' "$t/2.png"; txt "$F" 26 "$MAGENTA" 'syna' "$t/3.png"; txt "$F" 26 "$FAINT" ':~$ unlock ' "$t/4.png"
magick "$t/1.png" "$t/2.png" "$t/3.png" "$t/4.png" -background none +append PNG32:"$out/prompt.png"
txt "$F" 26 "$SIGNAL" '•' "$out/bullet.png"
txt "$F" 26 "$SIGNAL" '▋' "$out/cursor.png"
magick -size 760x60 xc:"$CARD" -fill none -stroke "$LINE" -strokewidth 2 -draw 'rectangle 1,1 758,58' PNG32:"$out/box.png"
txt "$F" 20 "$CRIMSON" '// access denied, try again' "$out/denied.png"
txt "$F" 20 "$SCARF"   '// caps lock is on'          "$out/capslock.png"
magick -size 400x3 xc:"$LINE"   PNG32:"$out/progress-box.png"
magick -size 400x3 xc:"$SIGNAL" PNG32:"$out/progress-bar.png"
txt "$F" 18 "$FAINT" '// code-signed by ' "$t/f1.png"; txt "$F" 18 "$SIGNAL" 'AdepT_X' "$t/f2.png"
magick "$t/f1.png" "$t/f2.png" -background none +append PNG32:"$out/footer.png"
echo "rendered $(ls "$out" | wc -l) images to $out"
