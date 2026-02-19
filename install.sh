#!/bin/bash
#
# Syna Rice Bootstrap Script
# Run after fresh CachyOS minimal (CLI) install
#
# Usage:
#   git clone https://github.com/AdeptOfficial/.dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles
#   ./install.sh [desktop|laptop]
#

set -euo pipefail

# Trap for cleanup on exit
SUDO_PID=""
cleanup() {
  [[ -n "$SUDO_PID" ]] && kill "$SUDO_PID" 2>/dev/null || true
}
trap cleanup EXIT
trap 'echo "Error at line $LINENO"; cleanup; exit 1' ERR

# Verify ~/.dotfiles exists
if [[ ! -d "$HOME/.dotfiles" ]]; then
  echo "Error: ~/.dotfiles directory not found"
  echo "Clone first: git clone https://github.com/AdeptOfficial/.dotfiles.git ~/.dotfiles"
  exit 1
fi

# Verify running from correct location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/stow-all.sh" ]]; then
  echo "Error: Must run from dotfiles root directory"
  exit 1
fi

# Verify repo integrity (no uncommitted changes blocking)
cd "$SCRIPT_DIR"
if [[ -d .git ]] && ! git diff --quiet HEAD 2>/dev/null; then
  echo "Warning: Uncommitted changes in dotfiles repo"
fi

# Initialize and verify submodules if any exist
if [[ -f .gitmodules ]]; then
  echo "Initializing git submodules..."
  git submodule update --init --recursive
  # Verify all submodules are properly initialized
  if git submodule status | grep -q '^-'; then
    echo "Error: Some submodules failed to initialize"
    git submodule status
    exit 1
  fi
fi

# Check required tools
for cmd in git sudo; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is required but not installed"
    exit 1
  fi
done

# Parse optional flags
FORCE_OVERWRITE=false
for arg in "$@"; do
  case "$arg" in
    --force) FORCE_OVERWRITE=true ;;
  esac
done

# Ensure AUR/yay prerequisites are installed (--needed skips if present)
sudo pacman -S --needed --noconfirm base-devel git

# Validate sudo works
if ! sudo -v; then
  echo "Error: sudo access required"
  exit 1
fi

# Keep sudo alive during script (with cleanup)
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════╗"
echo "║        Syna Rice Bootstrap Script         ║"
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
  rm -rf /tmp/yay
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  cd /tmp/yay && makepkg -si --noconfirm
  cd ~/.dotfiles
  rm -rf /tmp/yay
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
  yq jq gum stow git uwsm github-cli \
  libnotify xdg-utils xdg-user-dirs \
  fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool

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
  walker elephant elephant-desktopapplications \
  ghostty grimblast-git satty gpu-screen-recorder helium-browser-bin \
  wiremix bluetui eww xdg-terminal-exec vesktop

# ASUS G14 specific packages (laptop only)
if [[ "$PROFILE" == "laptop" ]]; then
  echo -e "${GREEN}[4b/9] Installing ASUS G14 packages...${NC}"
  sudo pacman -S --needed --noconfirm asusctl supergfxctl power-profiles-daemon
  yay -S --needed --noconfirm rog-control-center
fi

# VM-specific packages (only if running in a VM)
if [[ "$(systemd-detect-virt)" != "none" ]]; then
  echo -e "${GREEN}[4c/9] Installing VM guest tools...${NC}"
  sudo pacman -S --needed --noconfirm qemu-guest-agent spice-vdagent
  sudo systemctl enable qemu-guest-agent
  sudo systemctl enable spice-vdagentd
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
# 5b. Setup SDDM with autologin
# ============================================
echo -e "${GREEN}[5b/9] Setting up SDDM autologin...${NC}"
sudo pacman -S --needed --noconfirm sddm
sudo mkdir -p /etc/sddm.conf.d
cat <<EOF | sudo tee /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$USER
Session=hyprland-uwsm

[Theme]
Current=breeze
EOF
sudo systemctl enable sddm.service

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
for dir in hypr waybar walker mako alacritty ghostty kitty fish; do
  if [[ -d ~/.config/$dir && ! -L ~/.config/$dir ]]; then
    if [[ -d ~/.config/$dir.backup ]]; then
      echo "Backup already exists for $dir, skipping"
    else
      echo -e "${YELLOW}Backing up existing ~/.config/$dir${NC}"
      mv ~/.config/$dir ~/.config/$dir.backup
    fi
  fi
done

# Stow all packages
STOW_PACKAGES="hypr fish xdg waybar shell fastfetch themes rice scripts alacritty ghostty kitty swayosd walker mako btop eww satty"
for pkg in $STOW_PACKAGES; do
  if [[ -d "$pkg" ]]; then
    if ! stow "$pkg"; then
      echo "Stow failed for $pkg, trying restow..."
      stow -R "$pkg"
    fi
  fi
done

# Initialize XDG directories (graceful if command missing)
if command -v xdg-user-dirs-update &>/dev/null; then
  xdg-user-dirs-update
fi
mkdir -p ~/Pictures/Screenshots

# ============================================
# 7. Apply profile (local override pattern)
# ============================================
# Machine-specific configs go in .local.conf files (gitignored).
# Stowed configs source these files, allowing per-machine customization
# without git conflicts.
#
# Templates in hypr/.config/hypr/templates/:
# - *.laptop.example  = G14-specific
# - *.default.example = Generic/VM
# - *.desktop.example = Desktop reference
# ============================================

echo -e "${GREEN}[7/9] Applying $PROFILE profile...${NC}"

TEMPLATES_DIR="$HOME/.dotfiles/hypr/.config/hypr/templates"

# Determine effective profile (VM overrides user choice)
if [[ "$(systemd-detect-virt)" != "none" ]]; then
  EFFECTIVE_PROFILE="vm"
  echo -e "${YELLOW}VM detected - using default templates${NC}"
else
  EFFECTIVE_PROFILE="$PROFILE"
fi

# Get template path for a config file and profile
get_template() {
  local file="$1"  # monitors, input, or autostart
  local profile="$2"  # laptop, vm, or desktop
  case "$profile" in
    laptop)  echo "$TEMPLATES_DIR/${file}.laptop.example" ;;
    vm)      echo "$TEMPLATES_DIR/${file}.default.example" ;;
    desktop) echo "$TEMPLATES_DIR/${file}.desktop.example" ;;
  esac
}

# Create .local.conf if missing (idempotent)
create_local_if_missing() {
  local target="$1"
  local template="$2"
  if [[ -f "$target" && "$FORCE_OVERWRITE" != "true" ]]; then
    echo "  Keeping existing: $(basename "$target")"
    return
  fi
  if [[ -n "$template" && -f "$template" ]]; then
    cp "$template" "$target"
    echo "  Created: $(basename "$target") (from $(basename "$template"))"
  else
    touch "$target"
    echo "  Created: $(basename "$target") (empty)"
  fi
}

# Create .local.conf files from templates
echo "Creating machine-specific configs in ~/.config/hypr/:"
for f in monitors input autostart; do
  template="$(get_template "$f" "$EFFECTIVE_PROFILE")"
  create_local_if_missing "$HOME/.config/hypr/${f}.local.conf" "$template"
done

# Waybar workspaces local config (persistent workspace count per machine)
WAYBAR_TEMPLATES="$HOME/.dotfiles/waybar/.config/waybar/templates"
case "$EFFECTIVE_PROFILE" in
  laptop) WAYBAR_WS_TEMPLATE="$WAYBAR_TEMPLATES/workspaces.laptop.jsonc" ;;
  *)      WAYBAR_WS_TEMPLATE="$WAYBAR_TEMPLATES/workspaces.desktop.jsonc" ;;
esac
echo "Creating machine-specific configs in ~/.config/waybar/:"
create_local_if_missing "$HOME/.config/waybar/workspaces.local.jsonc" "$WAYBAR_WS_TEMPLATE"

# Migrate legacy configs if present (from old profile-switch pattern)
migrate_legacy_config() {
  local legacy="$1"
  local target="$2"
  [[ -f "$legacy" && ! -L "$legacy" ]] || return 0
  if [[ -f "$target" ]]; then
    echo -e "${YELLOW}  Found legacy: $(basename "$legacy") (target exists, skipping)${NC}"
  else
    mv "$legacy" "$target"
    echo "  Migrated: $(basename "$legacy") → $(basename "$target")"
  fi
}

echo "Checking for legacy configs to migrate:"
for f in monitors input autostart; do
  for suffix in desktop laptop default; do
    migrate_legacy_config "$HOME/.config/hypr/${f}.${suffix}.conf" "$HOME/.config/hypr/${f}.local.conf"
  done
done

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
if [[ -x ~/.local/bin/rice/syna-theme-set ]]; then
  ~/.local/bin/rice/syna-theme-set futurism 2>/dev/null || true
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
echo "  2. SDDM will auto-login and start Hyprland"
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
echo "  - Switch theme: syna-theme-set <name>"
echo "  - Install theme: syna-theme-install <name>"
echo "  - Menu: syna-menu (or SUPER+ALT+SPACE)"
echo ""
echo -e "${YELLOW}Note: If audio doesn't work after reboot, run:${NC}"
echo "  systemctl --user restart pipewire pipewire-pulse wireplumber"
echo ""
