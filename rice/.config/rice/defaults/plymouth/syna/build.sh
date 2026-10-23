#!/bin/bash
# Render the Syna Plymouth theme images from the AdepT brand (palette, JetBrains Mono, A emblem).
# Usage: build.sh [outdir]   (default: ./images). Needs ImageMagick 7 and JetBrains Mono.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); out=${1:-$here/images}; mkdir -p "$out"
F=$(fc-match -f '%{file}' 'JetBrains Mono:style=Regular'); FB=$(fc-match -f '%{file}' 'JetBrains Mono:style=Bold')
# AdepT palette (~/git/adeptproductions/branding/README.md)
INK='#eff8fa' FAINT='#7e95a0' LINE='#203039' CARD='#111a21' SIGNAL='#3fd4e6' MAGENTA='#e359c9' MATRIX='#3fe0a8' CRIMSON='#f0597f' SCARF='#dfa35c'
txt() { magick -background none -font "$1" -pointsize "$2" -fill "$3" label:"$4" PNG32:"$5"; }  # font size color text out
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT

magick "$here/src/emblem-a.png" -trim +repage -resize 180x180 PNG32:"$out/emblem.png"
txt "$FB" 32 "$MAGENTA" 'syna coming online' "$out/title.png"
txt "$FB" 32 "$MAGENTA" 'syna going dark'    "$out/title-dark.png"
txt "$F"  22 "$FAINT"   'waking syna'         "$out/status-1.png"
txt "$F"  22 "$FAINT"   'loading shards'      "$out/status-2.png"
txt "$F"  22 "$FAINT"   'mounting relays'     "$out/status-3.png"
txt "$F"  22 "$FAINT"   'see you soon, AdepT' "$out/status-dark.png"
# prompt, two lines like a real terminal: the command, then cryptsetup's passphrase prompt
# line 1: adept (cyan, AdepT) @ (faint) syna (magenta, Syna) :~ (faint) ❯ (cyan, like the shell) cryptsetup open syna (ink, typed)
pango() { printf '<span font="JetBrains Mono 13.5" foreground="%s">%s</span>' "$FAINT" "$1" > "$t/markup"; magick -background none -define pango:wrap=none pango:@"$t/markup" PNG32:"$2"; }
pango26() { printf '<span font="JetBrains Mono 19.5" foreground="%s">%s</span>' "$FAINT" "$1" > "$t/markup"; magick -background none -define pango:wrap=none pango:@"$t/markup" PNG32:"$2"; }
pango26 "<span foreground=\"$SIGNAL\">adept</span>@<span foreground=\"$MAGENTA\">syna</span>:~ <span foreground=\"$SIGNAL\">❯</span> <span foreground=\"$INK\">cryptsetup open syna</span>" "$out/prompt.png"
pango26 "Enter passphrase for syna: " "$out/prompt2.png"
txt "$F" 26 "$SIGNAL" '•' "$out/bullet.png"
txt "$F" 26 "$SIGNAL" '▋' "$out/cursor.png"
magick -size 760x100 xc:"$CARD" -fill none -stroke "$LINE" -strokewidth 2 -draw 'rectangle 1,1 758,98' PNG32:"$out/box.png"
txt "$F" 20 "$CRIMSON" '// access denied, try again' "$out/denied.png"
txt "$F" 20 "$SCARF"   '// caps lock is on'          "$out/capslock.png"
magick -size 400x3 xc:"$LINE"   PNG32:"$out/progress-box.png"
magick -size 400x3 xc:"$SIGNAL" PNG32:"$out/progress-bar.png"
# footer (boot and shutdown): the full AdepT signature as one Pango string, so spacing is exactly as written (separate labels trim spaces)
pango "// code-signed by <span foreground=\"$SIGNAL\">AdepT_X</span> · stay sad and dead <span foreground=\"$MAGENTA\">&lt;3</span>" "$out/footer.png"
echo "rendered $(ls "$out" | wc -l) images to $out"
