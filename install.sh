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

echo -e "${GREEN}Installing with profile: $PROFILE${NC}"
echo ""

# ============================================
# 1. Install yay (AUR helper)
# ============================================
echo -e "${GREEN}[1/8] Installing yay...${NC}"
if ! command -v yay &>/dev/null; then
  sudo pacman -S --needed --noconfirm git base-devel
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay && makepkg -si --noconfirm
  cd -
fi

# ============================================
# 2. Install pacman packages
# ============================================
echo -e "${GREEN}[2/8] Installing pacman packages...${NC}"
sudo pacman -S --needed --noconfirm \
  pipewire pipewire-pulse pipewire-alsa wireplumber \
  bluez bluez-utils \
  networkmanager \
  hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  swaybg swayosd waybar mako \
  brightnessctl playerctl upower wl-clipboard grim slurp \
  polkit-gnome gnome-keyring \
  nautilus gvfs gvfs-mtp gvfs-smb \
  alacritty fish starship \
  ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-liberation noto-fonts noto-fonts-emoji \
  yq jq gum stow git uwsm \
  vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver

# ============================================
# 3. Install AUR packages
# ============================================
echo -e "${GREEN}[3/8] Installing AUR packages...${NC}"
yay -S --needed --noconfirm \
  walker ghostty satty gpu-screen-recorder helium-browser \
  wiremix bluetui

# ASUS G14 specific packages (laptop only)
if [[ "$PROFILE" == "laptop" ]]; then
  echo -e "${GREEN}[3b/8] Installing ASUS G14 packages...${NC}"
  sudo pacman -S --needed --noconfirm asusctl supergfxctl power-profiles-daemon
  yay -S --needed --noconfirm rog-control-center
fi

# ============================================
# 4. Enable services
# ============================================
echo -e "${GREEN}[4/8] Enabling services...${NC}"
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service

if [[ "$PROFILE" == "laptop" ]]; then
  sudo systemctl enable --now supergfxd.service
  sudo systemctl enable --now power-profiles-daemon.service
fi

# ============================================
# 5. Stow dotfiles
# ============================================
echo -e "${GREEN}[5/8] Stowing dotfiles...${NC}"
cd ~/.dotfiles

# Remove conflicting files if they exist
rm -f ~/.bashrc ~/.bash_profile 2>/dev/null || true

./stow-all.sh

# ============================================
# 6. Apply profile
# ============================================
echo -e "${GREEN}[6/8] Applying $PROFILE profile...${NC}"
if [[ "$PROFILE" == "laptop" ]]; then
  cp ~/.dotfiles/hypr/.config/hypr/monitors.laptop.conf ~/.config/hypr/monitors.conf
  cp ~/.dotfiles/hypr/.config/hypr/input.laptop.conf ~/.config/hypr/input.conf
else
  # Desktop is default in dotfiles
  cp ~/.config/hypr/monitors.conf ~/.config/hypr/monitors.desktop.conf 2>/dev/null || true
  cp ~/.config/hypr/input.conf ~/.config/hypr/input.desktop.conf 2>/dev/null || true
fi

# ============================================
# 7. Set default browser
# ============================================
echo -e "${GREEN}[7/8] Setting default browser...${NC}"
xdg-settings set default-web-browser helium.desktop 2>/dev/null || true

# ============================================
# 8. Set default theme
# ============================================
echo -e "${GREEN}[8/8] Setting theme...${NC}"
if [[ -x ~/.local/bin/rice/adept-theme-set ]]; then
  ~/.local/bin/rice/adept-theme-set futurism
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
