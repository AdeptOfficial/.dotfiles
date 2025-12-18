#!/usr/bin/env bash
# Integrated CachyOS Setup: Apps Only

# --- App List ---
# Add standard packages to PACMAN_APPS
# Add Flatpaks to FLATPAK_APPS
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
    
    # Automatically enable and start service if the app is Tailscale
    if [ "$APP" == "tailscale" ]; then
        echo "Starting tailscaled service..."
        sudo systemctl enable --now tailscaled
    fi
done

# --- Flatpak Logic ---
if command -v flatpak &> /dev/null; then
    echo "📦 Installing Flatpak apps..."
    # Ensure flathub remote is added
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    for FLP in "${FLATPAK_APPS[@]}"; do
        echo "Installing Flatpak: $FLP"
        flatpak install -y flathub "$FLP"
    done
else
    echo "⚠️ Flatpak was not found, skipping Flatpak apps."
fi

echo "-----------------------------------------------"
echo "✅ Installation complete!"
if [[ " ${PACMAN_APPS[@]} " =~ " tailscale " ]]; then
    echo "To authenticate Tailscale, run: sudo tailscale up"
fi
echo "-----------------------------------------------"----"
