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

### 2. Core System Packages

```bash
# Hyprland and Wayland
sudo pacman -S hyprland hyprlock hypridle xdg-desktop-portal-hyprland

# Display and compositor
sudo pacman -S swaybg swayosd waybar

# App launcher and notifications
sudo pacman -S mako
yay -S walker

# Utilities
sudo pacman -S brightnessctl playerctl upower wl-clipboard grim slurp
sudo pacman -S polkit-gnome gnome-keyring

# Terminal & shell
sudo pacman -S alacritty fish starship
yay -S ghostty

# File management
sudo pacman -S nautilus xdg-desktop-portal-gtk

# Screenshot tool
yay -S satty

# Screen recording (GPU accelerated)
yay -S gpu-screen-recorder
```

### 3. Fonts

```bash
# Nerd Fonts (required for waybar/terminal icons)
sudo pacman -S ttf-jetbrains-mono-nerd ttf-firacode-nerd

# Additional fonts
sudo pacman -S ttf-liberation noto-fonts noto-fonts-emoji
```

### 4. Theme Dependencies

```bash
sudo pacman -S yq jq gum
```

### 5. Default Browser (Helium)

```bash
# Install Helium browser
yay -S helium-browser

# Set as default
xdg-settings set default-web-browser helium.desktop
```

### 6. Session Manager

```bash
# UWSM (Universal Wayland Session Manager)
sudo pacman -S uwsm
```

### 7. ASUS G14 Specific Packages (asus-linux.org)

These are community tools from [asus-linux.org](https://asus-linux.org), not official ASUS software.

```bash
# asus-linux tools (fan control, keyboard backlight, GPU switching)
sudo pacman -S asusctl supergfxctl

# Enable services
sudo systemctl enable --now supergfxd.service
systemctl --user enable --now asusd-user.service

# Power profiles daemon
sudo pacman -S power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon.service
```

### 8. AMD GPU Packages

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
  hyprland hyprlock hypridle swaybg swayosd waybar mako \
  brightnessctl playerctl upower wl-clipboard grim slurp \
  polkit-gnome gnome-keyring \
  alacritty fish starship \
  nautilus xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-liberation noto-fonts noto-fonts-emoji \
  yq jq gum stow git \
  vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver \
  asusctl supergfxctl power-profiles-daemon uwsm

# AUR packages
yay -S --needed walker ghostty satty gpu-screen-recorder helium-browser
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
adept-profile-switch laptop
```

### Step 4: Set Default Browser

```bash
xdg-settings set default-web-browser helium.desktop
```

### Step 5: Activate Theme

```bash
adept-theme-set futurism
```

### Step 6: Enable Services

```bash
# ASUS services
sudo systemctl enable --now supergfxd.service
systemctl --user enable --now asusd-user.service
sudo systemctl enable --now power-profiles-daemon.service
```

### Step 7: Start Hyprland

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

---

## Switching Between Desktop/Laptop

```bash
adept-profile-switch laptop   # On laptop
adept-profile-switch desktop  # On desktop
adept-profile-switch status   # Check current
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
