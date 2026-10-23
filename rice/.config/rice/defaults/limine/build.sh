#!/bin/bash
# SynaOS Limine background = the theme wallpaper's aurora + constellation, centre left empty for the menu,
# small emblem bottom-left, signature bottom. Rendered 2x, written as an exact 1920x1080 lossless PNG (~170 KB):
# with both monitors on, the firmware (GOP) runs the boot screen at 1920x1080 (observed 2026-10-22: the kernel's first
# framebuffer is 1080p). A 2560x1440 JPEG was stretched down by Limine and blurred thin lines and text; theme.conf
# shows this image `centered` (1:1, never resampled) with the base colour as backdrop.
# Run ./build.sh, then ./preview.sh, then syna-limine-theme apply. Guide: ~/.syna/guides/boot.md (Limine menu theme).
set -euo pipefail
W=5120 H=2880
E=~/git/adeptproductions/branding/art/emblem-a.png
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
python3 - "$t" "$W" "$H" <<'PY'
import random, sys; random.seed(7); t, W, H = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
pts = []
while len(pts) < 46:
    x, y = random.randint(0, W), random.randint(0, H)
    if ((x - W/2) / (W*0.30))**2 + ((y - H/2) / (H*0.36))**2 > 1: pts.append((x, y))
lines = [f"line {a[0]},{a[1]} {b[0]},{b[1]}" for a in pts
         for b in sorted(pts, key=lambda b: (a[0]-b[0])**2 + (a[1]-b[1])**2)[1:3]]
open(f"{t}/links.draw", "w").write(" ".join(lines))
open(f"{t}/nodes.draw", "w").write(" ".join(f"circle {x},{y} {x+4},{y}" for x, y in pts))
PY
printf '%s' '<span font="JetBrains Mono 30" foreground="#7e95a0">// code-signed by <span foreground="#3fd4e6">AdepT_X</span> · stay sad and dead <span foreground="#e359c9">&lt;3</span></span>' > "$t/m"
magick -background none pango:@"$t/m" "$t/sig.png"
magick -size ${W}x${H} xc:'#0a1014' \
  \( -size ${W}x${H} xc:none -fill '#3fd4e6' -draw 'ellipse 1520,2080 1680,720 0,360' -blur 0x480 -channel A -evaluate multiply 0.22 +channel \) -composite \
  \( -size ${W}x${H} xc:none -fill '#e359c9' -draw 'ellipse 3920,720 1440,600 0,360' -blur 0x520 -channel A -evaluate multiply 0.13 +channel \) -composite \
  \( -size ${W}x${H} xc:none -stroke '#3fd4e6' -strokewidth 2 -draw "@$t/links.draw" -channel A -evaluate multiply 0.10 +channel \) -composite \
  \( -size ${W}x${H} xc:none -fill '#3fd4e6' -draw "@$t/nodes.draw" -channel A -evaluate multiply 0.40 +channel \) -composite \
  \( "$E" -filter Lanczos -resize 300x300 \) -gravity southwest -geometry +150+150 -composite \
  "$t/sig.png" -gravity south -geometry +0+96 -composite \
  -filter Lanczos -resize 1920x1080 -strip -define png:compression-level=9 PNG24:"$(dirname "$0")/limine-wallpaper.png"
