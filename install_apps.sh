#!/usr/bin/env bash
# CachyOS + Syna Setup Script
# - Lightweight companion to install.sh (called by stow-all.sh)
# - System update + stow
# - No Flatpak

set -e

# -------------------------
# Packages
# -------------------------
PACMAN_APPS=(
  stow
)

echo "📦 System update + pacman apps..."
sudo pacman -Syu --needed --noconfirm "${PACMAN_APPS[@]}"

# -------------------------
# XDG / PATH sanity (native apps only)
# -------------------------
echo "🛠️ Ensuring clean XDG + PATH for Hyprland / Walker"

ENV_DIR="$HOME/.config/environment.d"
ENV_FILE="$ENV_DIR/10-path.conf"

mkdir -p "$ENV_DIR"

cat > "$ENV_FILE" <<'EOF'
# Native binaries only
PATH=/usr/local/bin:/usr/bin:$HOME/.local/bin
EOF

# -------------------------
# Desktop database refresh
# -------------------------
echo "🔄 Refreshing desktop databases..."
sudo update-desktop-database /usr/share/applications &>/dev/null || true
update-desktop-database "$HOME/.local/share/applications" &>/dev/null || true

# -------------------------
# Walker refresh
# -------------------------
echo "♻️ Refreshing Walker..."
if command -v syna-refresh-walker &>/dev/null; then
    syna-refresh-walker
fi

echo
echo "✅ DONE"
echo "➡️ pacman -Syu is the only updater"
echo "➡️ Reboot recommended to apply environment.d"
echo "➡️ Run: systemctl reboot"

