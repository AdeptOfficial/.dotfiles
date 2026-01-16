# ASUS ROG Zephyrus G14 2022 (GA402RJ) Setup Guide

## Hardware Specs

- **CPU:** AMD Ryzen 9 6900HS (Zen 3+, 8C/16T)
- **GPU:** AMD Radeon RX 6700S (dGPU) + Radeon 680M (iGPU)
- **Display:** 14" 2560x1600 (QHD+ 16:10) @ 120Hz
- **RAM:** 16GB/32GB DDR5

---

## Prerequisites

### 1. Base System

**Recommended OS:** CachyOS (Arch-based, optimized for AMD)

Install CachyOS with these repos enabled:
- `cachyos` (general packages)
- `cachyos-v3` (for Zen 3+ optimizations)

### 2. Audio (PipeWire)

```bash
# PipeWire audio stack
sudo pacman -S pipewire pipewire-pulse pipewire-alsa wireplumber

# Audio control TUI (optional)
yay -S wiremix
```

### 3. Bluetooth

```bash
sudo pacman -S bluez bluez-utils

# Enable bluetooth service
sudo systemctl enable --now bluetooth.service

# Bluetooth TUI (optional)
yay -S bluetui
```

### 4. Network

```bash
sudo pacman -S networkmanager networkmanager-openvpn

# Enable NetworkManager
sudo systemctl enable --now NetworkManager.service
```

### 5. Hyprland & Desktop

```bash
# Hyprland and Wayland
sudo pacman -S hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

# Display and compositor
sudo pacman -S swaybg swayosd waybar

# App launcher and notifications
sudo pacman -S mako
yay -S walker

# Utilities
sudo pacman -S brightnessctl playerctl upower wl-clipboard grim slurp

# Authentication
sudo pacman -S polkit-gnome gnome-keyring

# File management
sudo pacman -S nautilus gvfs gvfs-mtp gvfs-smb

# Terminal & shell
sudo pacman -S alacritty fish starship
yay -S ghostty

# Screenshot & recording
yay -S satty gpu-screen-recorder
```

### 6. Fonts

```bash
# Nerd Fonts (required for waybar/terminal icons)
sudo pacman -S ttf-jetbrains-mono-nerd ttf-firacode-nerd

# Additional fonts
sudo pacman -S ttf-liberation noto-fonts noto-fonts-emoji
```

### 7. Theme & Tools

```bash
sudo pacman -S yq jq gum stow git
```

### 8. Default Browser (Helium)

```bash
yay -S helium-browser
xdg-settings set default-web-browser helium.desktop
```

### 9. Session Manager

```bash
sudo pacman -S uwsm
```

### 10. ASUS G14 Specific (asus-linux.org)

Community tools from [asus-linux.org](https://asus-linux.org), not official ASUS software.

```bash
# asus-linux tools (fan control, keyboard backlight, GPU switching)
sudo pacman -S asusctl supergfxctl power-profiles-daemon

# Optional: GUI control center
yay -S rog-control-center

# Enable services
sudo systemctl enable --now supergfxd.service
sudo systemctl enable --now power-profiles-daemon.service
```

### 11. AMD GPU

```bash
# Vulkan drivers (RADV - recommended)
sudo pacman -S vulkan-radeon lib32-vulkan-radeon

# Video acceleration
sudo pacman -S libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau
```

---

## Quick Install (Copy-Paste)

```bash
# All pacman packages
sudo pacman -S --needed \
  pipewire pipewire-pulse pipewire-alsa wireplumber \
  bluez bluez-utils \
  networkmanager networkmanager-openvpn \
  hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  swaybg swayosd waybar mako \
  brightnessctl playerctl upower wl-clipboard grim slurp \
  polkit-gnome gnome-keyring \
  nautilus gvfs gvfs-mtp gvfs-smb \
  alacritty fish starship \
  ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-liberation noto-fonts noto-fonts-emoji \
  yq jq gum stow git uwsm \
  asusctl supergfxctl power-profiles-daemon \
  vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver

# AUR packages
yay -S --needed walker ghostty satty gpu-screen-recorder helium-browser \
  wiremix bluetui rog-control-center

# Enable services
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now supergfxd.service
sudo systemctl enable --now power-profiles-daemon.service
```

---

## Installation Steps

### Step 1: Clone Dotfiles

```bash
git clone https://github.com/AdeptOfficial/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### Step 2: Stow All Packages

```bash
cd ~/.dotfiles
./stow-all.sh
```

### Step 3: Apply Laptop Profile

```bash
syna-profile-switch laptop
```

### Step 4: Set Default Browser

```bash
xdg-settings set default-web-browser helium.desktop
```

### Step 5: Activate Theme

```bash
syna-theme-set futurism
```

### Step 6: Start Hyprland

```bash
uwsm start hyprland
```

---

## Post-Install Configuration

### GPU Mode

```bash
supergfxctl -g              # Check current
supergfxctl -m Integrated   # Battery (iGPU only)
supergfxctl -m Hybrid       # Auto-switch
supergfxctl -m Dedicated    # Performance (dGPU)
```

### Power Profiles

```bash
powerprofilesctl get              # Check current
powerprofilesctl set power-saver  # Battery
powerprofilesctl set balanced     # Default
powerprofilesctl set performance  # Plugged in
```

### Fan Control

```bash
asusctl profile -l              # List
asusctl profile -P Quiet        # Silent
asusctl profile -P Balanced     # Default
asusctl profile -P Performance  # Gaming
```

### Keyboard Backlight

```bash
asusctl -k off
asusctl -k low
asusctl -k med
asusctl -k high
```

### ROG Control Center (GUI)

```bash
rog-control-center
```

---

## Switching Between Desktop/Laptop

```bash
syna-profile-switch laptop   # On laptop
syna-profile-switch desktop  # On desktop
syna-profile-switch status   # Check current
```

---

## Config Differences

| Setting | Desktop | Laptop |
|---------|---------|--------|
| Monitor | 2560x1440 + 1920x1080 | 2560x1600 (single) |
| Scale | 1x | 1.25x |
| Mouse accel | flat (raw) | adaptive |
| Sensitivity | -0.3 | 0 |
| Gestures | disabled | enabled |
| Natural scroll | off | on |

---

## Troubleshooting

### No audio
```bash
# Check PipeWire is running
systemctl --user status pipewire pipewire-pulse wireplumber

# Restart audio
systemctl --user restart pipewire pipewire-pulse wireplumber
```

### No bluetooth
```bash
systemctl status bluetooth
sudo systemctl restart bluetooth
bluetoothctl power on
```

### Brightness keys not working
```bash
brightnessctl info
ls -la /sys/class/backlight/
```

### Trackpad not working
```bash
libinput list-devices | grep -A5 Touchpad
```

### GPU not switching
```bash
systemctl status supergfxd
supergfxctl -m Hybrid --force
```

### No network
```bash
systemctl status NetworkManager
nmcli device status
nmcli device wifi list
```
