#!/usr/bin/env bash
# Integrated CachyOS Setup: Apps & Environment

# --- App List ---
PACMAN_APPS=(
    "tailscale"
    "flatpak"
    "stow"
)

FLATPAK_APPS=(
    "com.discordapp.Discord"
)

# --- Execution ---

echo "🔄 Updating system database..."
sudo pacman -Syu --noconfirm

echo "📦 Installing Pacman apps..."
for APP in "${PACMAN_APPS[@]}"; do
    echo "Processing: $APP"
    sudo pacman -S --needed --noconfirm "$APP"
    
    if [ "$APP" == "tailscale" ]; then
        echo "Starting tailscaled service..."
        sudo systemctl enable --now tailscaled
    fi
done

# --- Flatpak Logic ---
if command -v flatpak &> /dev/null; then
    echo "📦 Installing Flatpak apps..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    for FLP in "${FLATPAK_APPS[@]}"; do
        echo "Installing Flatpak: $FLP"
        flatpak install -y flathub "$FLP"
    done

    # --- Force Update Desktop Database ---
    echo "Refresh app list in menu..."
    sudo update-desktop-database /var/lib/flatpak/exports/share/applications &> /dev/null
    update-desktop-database ~/.local/share/flatpak/exports/share/applications &> /dev/null
    update-desktop-database ~/.local/share/applications &> /dev/null

    # --- Fish Shell Path Integration ---
    FISH_CONF="$HOME/.config/fish/config.fish"
    if [ -f "$FISH_CONF" ]; then
        echo "Adding Flatpak paths to Fish config..."
        LINE_TO_ADD="set -gx PATH \$PATH /var/lib/flatpak/exports/bin"
        if ! grep -qF "$LINE_TO_ADD" "$FISH_CONF"; then
            echo -e "\n# Flatpak Binaries Path\n$LINE_TO_ADD" >> "$FISH_CONF"
        fi
    fi
else
    echo "⚠️ Flatpak was not found, skipping Flatpak apps."
fi

echo "-----------------------------------------------"
echo "✅ Installation complete!"
if [[ " ${PACMAN_APPS[@]} " =~ " tailscale " ]]; then
    echo "To authenticate Tailscale, run: sudo tailscale up"
fi
echo "-----------------------------------------------"
