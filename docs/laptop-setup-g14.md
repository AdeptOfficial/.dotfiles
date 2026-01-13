# ASUS ROG Zephyrus G14 2022 (GA402RJ) Setup Guide

## Hardware Specs

- **CPU:** AMD Ryzen 9 6900HS (Zen 3+, 8C/16T)
- **GPU:** AMD Radeon RX 6700S (dGPU) + Radeon 680M (iGPU)
- **Display:** 14" 2560x1600 (QHD+ 16:10) @ 120Hz
- **RAM:** 16GB/32GB DDR5

---

## Prerequisites

### 1. Base System (CachyOS recommended)

Install CachyOS with these repos enabled:
- `cachyos` (general packages)
- `cachyos-v3` (for Zen 3+ optimizations)

### 2. Required Packages

```bash
# Core desktop
sudo pacman -S hyprland waybar walker mako swayosd swaybg hypridle hyprlock

# Terminal & shell
sudo pacman -S alacritty ghostty fish starship

# Utilities
sudo pacman -S brightnessctl playerctl upower wl-clipboard grim slurp satty

# File management
sudo pacman -S nautilus xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

# Fonts (Nerd Fonts for icons)
sudo pacman -S ttf-jetbrains-mono-nerd ttf-firacode-nerd

# Theme dependencies
sudo pacman -S yq jq

# Screen recording (GPU accelerated)
yay -S gpu-screen-recorder

# App launcher background service
# Walker MUST run as a background service
# Added to autostart: walker --gapplication-service
```

### 3. ASUS G14 Specific Packages

```bash
# ASUS Linux tools (fan control, RGB, power profiles)
sudo pacman -S asusctl supergfxctl

# Enable services
sudo systemctl enable --now supergfxd.service
systemctl --user enable --now asusd-user.service

# Power profiles daemon (integrates with asusctl)
sudo pacman -S power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon.service
```

### 4. AMD GPU Packages

```bash
# Vulkan drivers (RADV is default, recommended)
sudo pacman -S vulkan-radeon lib32-vulkan-radeon

# Video acceleration
sudo pacman -S libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau

# Optional: ROCm for compute (large download)
# sudo pacman -S rocm-hip-sdk
```

---

## Installation Steps

### Step 1: Clone Dotfiles

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### Step 2: Install GNU Stow

```bash
sudo pacman -S stow
```

### Step 3: Stow All Packages

```bash
cd ~/.dotfiles
./stow-all.sh

# Or manually:
stow hypr waybar themes rice scripts alacritty ghostty kitty swayosd walker mako btop fish shell fastfetch xdg
```

### Step 4: Apply Laptop-Specific Configs

```bash
# Backup desktop configs
cp ~/.config/hypr/monitors.conf ~/.config/hypr/monitors.desktop.conf
cp ~/.config/hypr/input.conf ~/.config/hypr/input.desktop.conf

# Apply laptop configs
cp ~/.dotfiles/hypr/.config/hypr/monitors.laptop.conf ~/.config/hypr/monitors.conf
cp ~/.dotfiles/hypr/.config/hypr/input.laptop.conf ~/.config/hypr/input.conf
```

### Step 5: Start Hyprland

```bash
# If using UWSM (recommended)
uwsm start hyprland

# Or directly
Hyprland
```

---

## Post-Install Configuration

### GPU Mode (asusctl)

```bash
# Check current GPU mode
supergfxctl -g

# Available modes:
supergfxctl -m Integrated   # Battery saver (iGPU only)
supergfxctl -m Hybrid       # Auto-switch (default)
supergfxctl -m Dedicated    # Performance (dGPU only)
```

### Power Profiles

```bash
# Check current profile
powerprofilesctl get

# Available profiles:
powerprofilesctl set power-saver      # Battery
powerprofilesctl set balanced         # Default
powerprofilesctl set performance      # Plugged in
```

### Fan Control (asusctl)

```bash
# Check fan curve
asusctl profile -l

# Set profile
asusctl profile -P Quiet        # Silent
asusctl profile -P Balanced     # Default
asusctl profile -P Performance  # Gaming
```

### Keyboard Backlight

```bash
# Brightness (0-3)
asusctl -k low
asusctl -k med
asusctl -k high
asusctl -k off
```

---

## Switching Between Desktop/Laptop

### Quick Switch Script

Create `~/.local/bin/rice/adept-profile-switch`:

```bash
#!/bin/bash
case "$1" in
  desktop)
    cp ~/.config/hypr/monitors.desktop.conf ~/.config/hypr/monitors.conf
    cp ~/.config/hypr/input.desktop.conf ~/.config/hypr/input.conf
    hyprctl reload
    ;;
  laptop)
    cp ~/.dotfiles/hypr/.config/hypr/monitors.laptop.conf ~/.config/hypr/monitors.conf
    cp ~/.dotfiles/hypr/.config/hypr/input.laptop.conf ~/.config/hypr/input.conf
    hyprctl reload
    ;;
  *)
    echo "Usage: adept-profile-switch [desktop|laptop]"
    ;;
esac
```

---

## Troubleshooting

### Display not detected

```bash
# Check connected displays
hyprctl monitors

# If eDP-1 not showing, check kernel driver
lspci -k | grep -A3 VGA
```

### Brightness keys not working

```bash
# Test brightnessctl
brightnessctl info
brightnessctl set 50%

# Check permissions
ls -la /sys/class/backlight/
# Should show amdgpu_bl0 or similar
```

### Trackpad not working

```bash
# Check libinput devices
libinput list-devices | grep -A5 Touchpad

# Test input
libinput debug-events
```

### Screen tearing

```bash
# Enable VRR (Variable Refresh Rate) in monitors.conf
monitor = eDP-1, 2560x1600@120, 0x0, 1.25, vrr, 1
```

### GPU not switching

```bash
# Check supergfxd status
systemctl status supergfxd

# Force mode
supergfxctl -m Hybrid --force
```

---

## Differences from Desktop Config

| Setting | Desktop | Laptop |
|---------|---------|--------|
| Monitor | 2560x1440 + 1920x1080 | 2560x1600 (single) |
| Scale | 1x | 1.25x |
| Mouse accel | flat (raw) | adaptive |
| Sensitivity | -0.3 | 0 |
| Numlock | on | off |
| Gestures | disabled | enabled |
| Natural scroll | off | on |

---

## Files Modified for Laptop

- `~/.config/hypr/monitors.conf` - Display configuration
- `~/.config/hypr/input.conf` - Input device settings

All other configs (themes, waybar, keybindings, etc.) work unchanged.
