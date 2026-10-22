#!/bin/bash
# Live preview of the Syna Plymouth theme in a window (X11 renderer via Xwayland).
# Copies the theme files to /usr/share/plymouth/themes/syna; does NOT change the default theme
# and does NOT rebuild any boot image. Run from a terminal on the desktop; asks for sudo.
#
#   preview.sh          boot screen, live status, password prompt (type anything), wrong-password demo
#   preview.sh dark     shutdown screen
set -u
here=$(cd "$(dirname "$0")" && pwd)
log=/tmp/syna-plymouth-preview.log
[[ -n ${DISPLAY:-} ]] || { echo "No DISPLAY: run this from a terminal on the desktop."; exit 1; }

sudo install -d -m 755 /usr/share/plymouth/themes/syna
sudo install -m 644 "$here"/syna.plymouth "$here"/syna.script "$here"/images/*.png /usr/share/plymouth/themes/syna/

mode=boot; [[ ${1:-} == dark ]] && mode=shutdown
sudo pkill -x plymouthd 2>/dev/null

# plymouthd must run as root, but Xwayland only admits localuser:adept. Grant root access for the
# preview only (what `xhost +si:localuser:root` does, via python-xlib) and always take it back.
xaccess() {
  python3 -I - "$1" <<'PY'
import sys
from Xlib import X, display
d = display.Display()
d.change_hosts(X.HostInsert if sys.argv[1] == "grant" else X.HostDelete, 5, b"localuser\0root\0")
d.sync()
PY
}
cleanup() { sudo plymouth quit 2>/dev/null; sudo pkill -x plymouthd 2>/dev/null; xaccess revoke; }
trap cleanup EXIT
trap 'exit 130' INT TERM
xaccess grant || { echo "Could not grant root access to the X display (python-xlib missing?)"; exit 1; }
# plymouth.ignore-udev: without it plymouthd goes for the DRM display (owned by Hyprland, so nothing
# shows); ignoring udev makes it use the X11 renderer because DISPLAY is set. setsid: no controlling
# tty, so the debug trace goes only to the log file instead of flooding this terminal.
sudo setsid env DISPLAY="$DISPLAY" XAUTHORITY="${XAUTHORITY:-}" plymouthd --mode="$mode" \
  --kernel-command-line="splash plymouth.splash=syna plymouth.ignore-udev" --debug-file="$log" \
  --pid-file=/tmp/syna-plymouth-preview.pid </dev/null >/dev/null 2>&1
sleep 1
pgrep -x plymouthd >/dev/null || { echo "plymouthd did not start; see $log"; exit 1; }
sudo plymouth show-splash
step() { echo "· $1"; sleep "${2:-3}"; }

if [[ $mode == shutdown ]]; then
  step "shutdown screen (8 s)" 8
else
  step "booting: status line cycles" 4
  for unit in "Network Manager" "Bluetooth service" "Login Service" "Syna relays"; do
    sudo plymouth update --status="$unit"; step "live status: $unit" 1.5
  done
  echo "· unlock prompt: click the Plymouth window, type anything + Enter there (discarded). Try Caps Lock."
  sudo plymouth ask-for-password --prompt="Passphrase" >/dev/null
  echo "· second prompt = the wrong-password view: type in the window again + Enter"
  sudo plymouth ask-for-password --prompt="Passphrase" >/dev/null
  sudo plymouth display-message --text="message line test"; step "message line" 3
fi

sudo plymouth quit
sudo chmod 644 "$log"
xaccess revoke; trap - EXIT
echo
if sudo grep -qiE 'parser error|execution error' "$log"; then
  echo "SCRIPT ERRORS (blockers):"; sudo grep -iE 'parser error|execution error' "$log" | head
else
  echo "No script errors in $log"
fi
