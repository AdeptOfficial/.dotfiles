
#!/usr/bin/env bash
# Omarchy / CachyOS Setup Script
# - Updates Omarchy
# - Ensures Walker works
# - Installs Flatpak + Discord
# - Fixes XDG + PATH the CORRECT way (environment.d)
# - Makes Discord appear in Walker

set -e

PACMAN_APPS=("tailscale" "flatpak" "stow")
FLATPAK_APPS=("com.discordapp.Discord")

echo "🔄 Updating Omarchy..."
if command -v omarchy-update &>/dev/null; then
    omarchy-update
else
    echo "⚠️ omarchy-update not found, skipping"
fi

echo "📦 System update + pacman apps..."
sudo pacman -Syu --needed --noconfirm "${PACMAN_APPS[@]}"

echo "🌐 Enabling Tailscale..."
sudo systemctl enable --now tailscaled

# -------------------------
# Flatpak setup
# -------------------------
echo "📦 Setting up Flatpak..."
flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo

for FLP in "${FLATPAK_APPS[@]}"; do
    flatpak install -y flathub "$FLP"
done

# -------------------------
# CRITICAL FIX (Omarchy / Walker)
# -------------------------
echo "🛠️ Fixing XDG + PATH for Hyprland / Walker (environment.d)"

ENV_DIR="$HOME/.config/environment.d"
ENV_FILE="$ENV_DIR/flatpak.conf"

mkdir -p "$ENV_DIR"

cat > "$ENV_FILE" <<'EOF'
# Flatpak paths for Hyprland / Walker
XDG_DATA_DIRS=/var/lib/flatpak/exports/share:/usr/share:$HOME/.local/share/flatpak/exports/share
PATH=/var/lib/flatpak/exports/bin:$HOME/.local/share/flatpak/exports/bin:/usr/local/bin:/usr/bin
EOF

# -------------------------
# Desktop database refresh
# -------------------------
echo "🔄 Refreshing desktop databases..."
sudo update-desktop-database /var/lib/flatpak/exports/share/applications &>/dev/null || true
update-desktop-database "$HOME/.local/share/flatpak/exports/share/applications" &>/dev/null || true

# -------------------------
# Walker refresh
# -------------------------
echo "♻️ Refreshing Walker..."
if command -v omarchy-refresh-walker &>/dev/null; then
    omarchy-refresh-walker
fi

echo
echo "✅ DONE"
echo "➡️ IMPORTANT: Reboot is REQUIRED (logout is unreliable on Omarchy)"
echo "➡️ Run: systemctl reboot"

