#!/bin/bash
# Combined Setup: Install Apps then Stow Dotfiles

# 1. Run the App Installation Script first
if [ -f "./install_apps.sh" ]; then
    echo "🚀 Starting app installation..."
    chmod +x install_apps.sh
    ./install_apps.sh
else
    echo "⚠️ install_apps.sh not found in the current directory. Skipping."
fi

# 2. Proceed with stowing dotfiles using --adopt
echo "🔄 Stowing all dotfiles with conflict resolution (--adopt)..."

# Core configs
stow --adopt hypr
stow --adopt fish
stow --adopt xdg
stow --adopt waybar
stow --adopt shell
stow --adopt fastfetch

# Rice configs (migrated from omarchy)
stow --adopt themes
stow --adopt rice
stow --adopt scripts
stow --adopt alacritty
stow --adopt ghostty
stow --adopt kitty
stow --adopt swayosd
stow --adopt walker
stow --adopt mako
stow --adopt btop
stow --adopt eww

echo "✅ All dotfiles stowed! (Symlinks established.)"

# --- Automatic Git Cleanup ---
echo ""
echo "⚠️ Cleaning up adopted default config files in the Git repository..."

PACKAGES="hypr fish xdg shell waybar fastfetch themes rice scripts alacritty ghostty kitty swayosd walker mako btop eww" 

# This command checks out your saved content from the Git index, 
# overwriting the temporary default files that Stow adopted.
git checkout $PACKAGES

echo "✅ Git repository cleaned. Your symlinks now point to your desired content."
echo ""
echo "Restart your terminal or run: exec fish"
