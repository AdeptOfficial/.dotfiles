#!/bin/bash
#
# Adept Rice Bootstrap Script
# Run after fresh CachyOS minimal (CLI) install
#
# Usage:
#   git clone https://github.com/AdeptOfficial/.dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles
#   ./install.sh [desktop|laptop]
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════╗"
echo "║       Adept Rice Bootstrap Script         ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# Detect profile
PROFILE="${1:-}"
if [[ -z "$PROFILE" ]]; then
  echo -e "${YELLOW}Select profile:${NC}"
  echo "  1) desktop - Multi-monitor, gaming mouse"
  echo "  2) laptop  - ASUS G14, trackpad"
  read -p "Choice [1/2]: " choice
  case "$choice" in
    1|desktop) PROFILE="desktop" ;;
    2|laptop)  PROFILE="laptop" ;;
    *) echo "Invalid choice"; exit 1 ;;
  esac
fi

# ============================================
# Detect hardware and show summary
# ============================================
GPU_LINE=$(lspci | grep -i vga | head -1)
if echo "$GPU_LINE" | grep -qi "amd\|radeon"; then
  GPU_TYPE="AMD"
  GPU_PACKAGES="vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver"
elif echo "$GPU_LINE" | grep -qi "nvidia"; then
  GPU_TYPE="NVIDIA"
  GPU_PACKAGES="nvidia-dkms nvidia-utils lib32-nvidia-utils"
elif echo "$GPU_LINE" | grep -qi "intel"; then
  GPU_TYPE="Intel"
  GPU_PACKAGES="vulkan-intel lib32-vulkan-intel intel-media-driver"
else
  GPU_TYPE="Unknown"
  GPU_PACKAGES="(none - manual install required)"
fi

echo ""
echo -e "${GREEN}Installation Summary:${NC}"
echo "─────────────────────────────────────────────"
echo -e "  Profile:     ${YELLOW}$PROFILE${NC}"
echo -e "  GPU:         ${YELLOW}$GPU_TYPE${NC}"
echo -e "  GPU Driver:  $GPU_PACKAGES"
if [[ "$PROFILE" == "laptop" ]]; then
  echo -e "  Extras:      asusctl supergfxctl rog-control-center"
fi
echo "─────────────────────────────────────────────"
echo ""
read -p "Proceed with installation? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Installation cancelled."
  exit 0
fi
echo ""

# ============================================
# 0. Handle PulseAudio -> PipeWire migration
# ============================================
# Some Arch-based distros still ship PulseAudio. Remove it first to avoid conflicts.
echo -e "${GREEN}[0/9] Checking audio backend...${NC}"
if pacman -Qs pulseaudio > /dev/null 2>&1; then
  echo -e "${YELLOW}PulseAudio detected. Replacing with PipeWire...${NC}"
  sudo pacman -Rdd --noconfirm pulseaudio pulseaudio-alsa 2>/dev/null || true
fi

# ============================================
# 1. Install yay (AUR helper)
# ============================================
echo -e "${GREEN}[1/9] Installing yay...${NC}"
if ! command -v yay &>/dev/null; then
  sudo pacman -S --needed --noconfirm git base-devel
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay && makepkg -si --noconfirm
  cd ~/.dotfiles
fi

# ============================================
# 2. Install PipeWire audio (do this first!)
# ============================================
# Installing PipeWire first prevents "stuck" installations on some distros
echo -e "${GREEN}[2/9] Installing PipeWire audio...${NC}"
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-pulse pipewire-alsa pipewire-audio wireplumber

# ============================================
# 3. Install core pacman packages
# ============================================
echo -e "${GREEN}[3/9] Installing core packages...${NC}"
sudo pacman -S --needed --noconfirm \
  bluez bluez-utils \
  networkmanager \
  hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  swaybg swayosd waybar mako \
  brightnessctl playerctl upower wl-clipboard grim slurp \
  polkit-gnome gnome-keyring \
  nautilus gvfs gvfs-mtp gvfs-smb \
  alacritty fish starship \
  ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-liberation noto-fonts noto-fonts-emoji \
  yq jq gum stow git uwsm

# ============================================
# 3b. Install GPU drivers (auto-detected)
# ============================================
echo -e "${GREEN}[3b/9] Installing $GPU_TYPE GPU drivers...${NC}"
if [[ "$GPU_TYPE" != "Unknown" ]]; then
  sudo pacman -S --needed --noconfirm $GPU_PACKAGES
else
  echo -e "${YELLOW}Unknown GPU, skipping driver install${NC}"
fi

# ============================================
# 4. Install AUR packages
# ============================================
echo -e "${GREEN}[4/9] Installing AUR packages...${NC}"
yay -S --needed --noconfirm \
  walker ghostty satty gpu-screen-recorder helium-browser \
  wiremix bluetui

# ASUS G14 specific packages (laptop only)
if [[ "$PROFILE" == "laptop" ]]; then
  echo -e "${GREEN}[4b/9] Installing ASUS G14 packages...${NC}"
  sudo pacman -S --needed --noconfirm asusctl supergfxctl power-profiles-daemon
  yay -S --needed --noconfirm rog-control-center
fi

# ============================================
# 5. Enable services
# ============================================
echo -e "${GREEN}[5/9] Enabling services...${NC}"
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service

# Enable user PipeWire services
systemctl --user enable --now pipewire.service 2>/dev/null || true
systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
systemctl --user enable --now wireplumber.service 2>/dev/null || true

if [[ "$PROFILE" == "laptop" ]]; then
  sudo systemctl enable --now supergfxd.service
  sudo systemctl enable --now power-profiles-daemon.service
fi

# ============================================
# 6. Stow dotfiles
# ============================================
echo -e "${GREEN}[6/9] Stowing dotfiles...${NC}"
cd ~/.dotfiles

# Remove conflicting files (only if not already symlinks from stow)
if [[ ! -L ~/.bashrc ]]; then
  rm -f ~/.bashrc ~/.bash_profile 2>/dev/null || true
fi

# Backup existing configs that conflict with stow
for dir in hypr waybar walker mako alacritty ghostty kitty; do
  if [[ -d ~/.config/$dir && ! -L ~/.config/$dir ]]; then
    echo -e "${YELLOW}Backing up existing ~/.config/$dir${NC}"
    mv ~/.config/$dir ~/.config/$dir.backup
  fi
done

# Stow all packages
STOW_PACKAGES="hypr fish xdg waybar shell fastfetch themes rice scripts alacritty ghostty kitty swayosd walker mako btop"
for pkg in $STOW_PACKAGES; do
  if [[ -d "$pkg" ]]; then
    stow "$pkg" 2>/dev/null || stow -R "$pkg"
  fi
done

# ============================================
# 7. Apply profile
# ============================================
echo -e "${GREEN}[7/9] Applying $PROFILE profile...${NC}"
if [[ "$PROFILE" == "laptop" ]]; then
  cp ~/.dotfiles/hypr/.config/hypr/monitors.laptop.conf ~/.config/hypr/monitors.conf
  cp ~/.dotfiles/hypr/.config/hypr/input.laptop.conf ~/.config/hypr/input.conf
else
  # Desktop is default in dotfiles, backup for switching later
  cp ~/.config/hypr/monitors.conf ~/.config/hypr/monitors.desktop.conf 2>/dev/null || true
  cp ~/.config/hypr/input.conf ~/.config/hypr/input.desktop.conf 2>/dev/null || true
fi

# ============================================
# 8. Set default browser
# ============================================
echo -e "${GREEN}[8/9] Setting default browser...${NC}"
xdg-settings set default-web-browser helium.desktop 2>/dev/null || true

# ============================================
# 9. Set default theme
# ============================================
echo -e "${GREEN}[9/9] Setting theme...${NC}"
export PATH="$HOME/.local/bin/rice:$PATH"
if [[ -x ~/.local/bin/rice/adept-theme-set ]]; then
  ~/.local/bin/rice/adept-theme-set futurism 2>/dev/null || true
fi

# ============================================
# Done!
# ============================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗"
echo "║            Installation Complete!          ║"
echo "╚═══════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot: sudo reboot"
echo "  2. Login and start Hyprland: uwsm start hyprland"
echo ""
if [[ "$PROFILE" == "laptop" ]]; then
  echo "G14 Controls:"
  echo "  - GPU mode: supergfxctl -m [Integrated|Hybrid|Dedicated]"
  echo "  - Fan profile: asusctl profile -P [Quiet|Balanced|Performance]"
  echo "  - Power: powerprofilesctl set [power-saver|balanced|performance]"
  echo "  - GUI: rog-control-center"
  echo ""
fi
echo "Useful commands:"
echo "  - Switch theme: adept-theme-set <name>"
echo "  - Install theme: adept-theme-install <name>"
echo "  - Menu: adept-menu (or SUPER+ALT+SPACE)"
echo ""
echo -e "${YELLOW}Note: If audio doesn't work after reboot, run:${NC}"
echo "  systemctl --user restart pipewire pipewire-pulse wireplumber"
echo ""
