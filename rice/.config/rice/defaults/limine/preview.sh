#!/bin/bash
# Boot the real Limine (same version as the system) in QEMU/OVMF with a theme block + mock entries; screenshot the menu.
# Usage: preview.sh [out.png]   (this folder's theme.conf + limine-wallpaper.jpg; nothing on /boot is read or written)
set -euo pipefail
here=$(dirname "$(readlink -f "$0")"); theme=$here/theme.conf wall=$here/limine-wallpaper.jpg out=${1:-$HOME/.cache/syna/limine-preview.png}; mkdir -p "$(dirname "$out")"
t=$(mktemp -d); trap 'kill $(cat "$t/pid" 2>/dev/null) 2>/dev/null; rm -rf "$t"' EXIT
{ printf 'timeout: no\ndefault_entry: 2\nremember_last_entry: yes\n\n'; cat "$theme"; cat <<'ENT'

/+CachyOS
  //linux-cachyos
    protocol: efi
    path: boot():/none.efi
  //linux-cachyos-vfio
    protocol: efi
    path: boot():/none.efi
  //linux-cachyos-lts
    protocol: efi
    path: boot():/none.efi
  //Snapshots
    protocol: efi
    path: boot():/none.efi

/+Other systems and bootloaders
  //Windows Boot Manager
    protocol: efi
    path: boot():/none.efi
/Limine
    protocol: efi
    path: boot():/none.efi
/EFI fallback
    protocol: efi
    path: boot():/none.efi
ENT
} > "$t/limine.conf"
img=$t/esp.img
truncate -s 64M "$img" && mkfs.fat -F 32 "$img" >/dev/null
mmd -i "$img" ::/EFI ::/EFI/BOOT ::/syna
mcopy -i "$img" /usr/share/limine/BOOTX64.EFI ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$img" "$t/limine.conf" ::/limine.conf
mcopy -i "$img" "$wall" ::/syna/limine-wallpaper.jpg
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$t/vars.fd"
qemu-system-x86_64 -machine q35 -m 512 -display none -daemonize -pidfile "$t/pid" \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$t/vars.fd" \
  -drive format=raw,file="$img" -device VGA,xres=2560,yres=1440 \
  -monitor unix:"$t/mon",server,nowait
sleep "${WAIT:-9}"
printf 'screendump %s\n' "$t/s.ppm" | python3 -c "
import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.connect('$t/mon'); time.sleep(.3); s.recv(4096)
s.sendall(sys.stdin.read().encode()); time.sleep(1.5)"
magick "$t/s.ppm" "$out" && magick identify "$out"
command -v imv >/dev/null && setsid imv "$out" >/dev/null 2>&1 < /dev/null &
