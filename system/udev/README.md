# udev rules (system files, not stowed)

Copied to `/etc/udev/rules.d/` by hand; stow does not manage `/etc`.

| File | Device | Why |
|---|---|---|
| `70-wlmouse.rules` | WLMOUSE (vendor `36a7`, e.g. BEAST G 8K receiver) | Web configurator (WebHID, Chromium-based browser) needs the logged-in user on `/dev/hidraw*` |
| `70-melgeek.rules` | MelGeek REAL67 (`0416:0112` only; the vendor ID is shared with the 8.8" LED screen) | Same, for the keyboard's web configurator |

`TAG+="uaccess"` grants the active seat user an ACL, like Steam's controller rules. Install:

```bash
sudo cp system/udev/*.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=hidraw
```

Check: `getfacl -p /dev/hidraw* | grep -B1 "user:$USER"`.
