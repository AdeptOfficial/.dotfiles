# Adept Rice Dotfiles

Custom dotfiles for CachyOS (Arch-based) with Hyprland using GNU Stow.

## Features

- **Hyprland**: Window manager with custom keybindings, hyprlock, hypridle
- **Waybar**: Status bar configuration
- **Theming**: Multiple themes with easy switching (futurism, ado, catppuccin, dreamwave, gruvbox, nord, sapphire, tokyo-night)
- **Terminals**: Ghostty, Alacritty, Kitty configurations
- **Fish Shell**: Shell config with Starship prompt
- **Walker**: Application launcher
- **Mako**: Notification daemon
- **Helium**: Default browser
- **Rice Scripts**: 100+ utility scripts for system management
- **Profile Support**: Desktop and laptop (ASUS G14) profiles
- **Auto GPU Detection**: AMD, NVIDIA, and Intel driver installation

## Fresh Install (CachyOS Minimal)

```bash
# Clone dotfiles
git clone https://github.com/adeptofficial/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Run bootstrap (will prompt for profile)
./install.sh

# Or specify profile directly
./install.sh desktop
./install.sh laptop
```

The install script will:
1. Install yay (AUR helper)
2. Install PipeWire audio
3. Install core packages (Hyprland, Waybar, terminals, fonts, etc.)
4. Auto-detect and install GPU drivers
5. Install AUR packages (Walker, Ghostty, etc.)
6. Enable system services (including SDDM autologin)
7. Stow all dotfiles
8. Apply selected profile (auto-detects VMs)
9. Set default theme (futurism)

After reboot, SDDM will auto-login and start Hyprland via UWSM.

## Existing System (Stow Only)

```bash
cd ~/.dotfiles
./stow-all.sh

# Restart terminal
exec fish

# Reload Hyprland
hyprctl reload
```

## Directory Structure

```
.dotfiles/
├── hypr/           # Hyprland config (hyprland, hyprlock, hypridle)
├── waybar/         # Waybar status bar
├── fish/           # Fish shell config
├── shell/          # Starship prompt
├── themes/         # Theme definitions and templates
├── rice/           # Rice configuration
├── scripts/        # syna-* utility scripts
├── alacritty/      # Alacritty terminal
├── ghostty/        # Ghostty terminal
├── kitty/          # Kitty terminal
├── walker/         # Application launcher
├── mako/           # Notification daemon
├── swayosd/        # SwayOSD (volume/brightness overlay)
├── btop/           # System monitor
├── fastfetch/      # System info display
├── xdg/            # Default applications
├── docs/           # Documentation
├── install.sh      # Full bootstrap script
├── install_apps.sh # App installation
└── stow-all.sh     # Stow-only script
```

## Theming

Switch themes using the rice scripts:

```bash
# List available themes
syna-theme-list

# Set a theme
syna-theme-set futurism
syna-theme-set catppuccin
syna-theme-set tokyo-night

# Install new themes
syna-theme-install <name>
```

Available themes: ado, catppuccin, dreamwave, futurism, gruvbox, nord, sapphire, tokyo-night

## Custom Aliases

Located in `fish/.config/fish/conf.d/aliases.fish`:

### Docker
- `dps` - docker ps
- `dcu` - docker compose up -d
- `dcd` - docker compose down
- `dcr` - docker compose restart
- `dlog` - docker compose logs -f

### Home Assistant
- `ha` - docker exec into home-assistant
- `ha-restart` - restart home-assistant container
- `ha-logs` - follow home-assistant logs

### Ollama
- `ollama-gpu` - check GPU status
- `ollama-logs` - follow ollama logs
- `ollama-restart` - restart ollama container

### System
- `update` - sudo pacman -Syu
- `clean` - sudo pacman -Sc

### Navigation
- `..` - cd ..
- `...` - cd ../..
- `dots` - cd ~/.dotfiles

### Git
- `gs` - git status
- `ga` - git add
- `gc` - git commit -m
- `gp` - git push
- `gl` - git pull

## Rice Scripts

The `scripts/` package includes 100+ utilities prefixed with `syna-`:

```bash
# System
syna-menu              # Main menu (SUPER+ALT+SPACE)
syna-update            # System update
syna-lock-screen       # Lock screen

# Theming
syna-theme-set         # Change theme
syna-theme-list        # List themes
syna-theme-install     # Install theme

# Launchers
syna-launch-browser    # Open browser
syna-launch-terminal   # Open terminal
syna-launch-walker     # Application launcher

# Screenshots
syna-cmd-screenshot    # Take screenshot
syna-cmd-screenrecord  # Screen recording

# Toggles
syna-toggle-waybar     # Toggle status bar
syna-toggle-nightlight # Toggle night light
```

## Machine-Specific Configs

Some configs vary by machine (monitors, workspaces, preferences). The pattern:

| File | Description |
|------|-------------|
| `*.conf` | Stowed default (primary desktop config) |
| `*.default.conf` | Generic template (VMs, fresh installs) |
| `*.laptop.conf` | G14-specific settings |

**Files with this pattern:**
- `monitors.conf` - Monitor layout and workspaces
- `autostart.conf` - Startup apps and workspace assignments
- `input.conf` - Mouse/keyboard preferences
- `ghostty/config` - Terminal preferences

**For new machines:**
- **Laptop**: `./install.sh laptop` (uses `*.laptop.conf`)
- **VM**: Auto-detected, uses `*.default.conf`
- **New desktop**: Customize `~/.config/hypr/*.conf` after install

## ASUS G14 Laptop

The laptop profile includes support for ASUS G14:

```bash
# GPU switching
supergfxctl -m Integrated
supergfxctl -m Hybrid
supergfxctl -m Dedicated

# Fan profiles
asusctl profile -P Quiet
asusctl profile -P Balanced
asusctl profile -P Performance

# Power profiles
powerprofilesctl set power-saver
powerprofilesctl set balanced
powerprofilesctl set performance

# GUI
rog-control-center
```

## Testing in VMs (Proxmox)

For testing install.sh on fresh CachyOS minimal:

```bash
# Connect via SPICE (better than noVNC)
# 1. In Proxmox web UI: VM → Console → SPICE dropdown
# 2. Downloads a .vv file
# 3. Open with:
remote-viewer ~/Downloads/*.vv

# Or install virt-viewer if not present
sudo pacman -S virt-viewer
```

**VM setup notes:**
- Use QXL display for SPICE support
- install.sh auto-detects VMs and uses generic configs
- qemu-guest-agent installed automatically in VMs

## Making Changes

```bash
# Edit configs directly (changes apply via symlinks)
nvim ~/.dotfiles/hypr/.config/hypr/bindings.conf
nvim ~/.dotfiles/fish/.config/fish/conf.d/aliases.fish
nvim ~/.dotfiles/shell/.config/starship.toml

# For Fish changes, restart terminal
exec fish

# For Hyprland changes
hyprctl reload

# Commit changes
cd ~/.dotfiles
git add .
git commit -m "Update config"
git push
```
