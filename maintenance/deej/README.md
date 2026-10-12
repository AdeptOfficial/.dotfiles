# Deej local build and deployment

The five-slider controller uses a Python MessagePack-to-deej adapter. The client is pinned to omriharel/deej commit `7567f83f2773e40cb950101d0784c96b1e566509` (v0.9.10), with a fallback from missing/empty `application.process.binary` to `application.name`. This is required for native CS2 audio. Existing binary matching takes priority; slider 5 remains explicitly games-only.

Full operations and troubleshooting: https://github.com/AdeptOfficial/syna-docs/blob/main/guides/deej.md (private).

## Build

Requires Git, Go, patch, pkg-config, a C compiler and development files for GTK3, WebKitGTK 4.1 and Ayatana AppIndicator. Runtime adapter requires Python and pyserial. This rebuild downloads the pinned upstream source/dependency and applies the two reviewed patches; no binary is stored in Git.

From an empty build directory, set `DEEJ_PATCHES` to the absolute path of this directory:

```bash
DEEJ_PATCHES="$HOME/.dotfiles/maintenance/deej"
git clone https://github.com/omriharel/deej.git source
cd source
git checkout 7567f83f2773e40cb950101d0784c96b1e566509
go mod download github.com/getlantern/systray
cp -R "$(go env GOMODCACHE)/github.com/getlantern/systray@v0.0.0-20200324212034-d3ab4fd25d99" local-systray
chmod -R u+w local-systray
patch -p1 -d local-systray < "$DEEJ_PATCHES/deej-systray-compat.patch"
git apply "$DEEJ_PATCHES/deej-pipewire.patch"
go build -o deej-fixed -ldflags '-s -w -X main.gitCommit=7567f83-pipewire -X main.versionTag=v0.9.10 -X main.buildType=local-fix' ./cmd
```

`local-fix` preserves the verified installation's debug logging to the user journal. `release` instead logs at info level to `~/.config/deej/logs/deej-latest-run.log`. Build passed on the desktop with a tray deprecated-API warning; the source patch was verified through physical CS2/Silksong volume tests.

## Deploy deliberately

The `deej/` directory is a Stow package, not automatically enabled by the existing installer. Inspect and back up existing target files; use `stow -n -v deej` to preview conflicts. Do not use `--adopt` or overwrite existing live config blindly. Resolve conflicts before running `stow deej`.

Install the built executable separately at `~/.local/bin/deej`, retaining a rollback copy. Stop only the deej user service while replacing its binary. Then run `systemctl --user daemon-reload` and `systemctl --user enable --now deej`. This publication does not re-stow or alter the already-working installation.

Check `journalctl --user -u deej`, have an app play audio, and move each physical slider to verify its stream volume. The hardware uses 115200 baud; the pseudo-terminal exposed to deej uses the configured 9600 baud. Do not change these to match. Recheck the stable USB device path on another machine.

Preserve these patches across updates. Original binary rollback on the current desktop is `~/.local/bin/deej.before-pipewire-fix`; it lacks the CS2 fix. Clean-install deployment remains untested.
