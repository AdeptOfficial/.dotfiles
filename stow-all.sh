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

# Note: Since you've moved Discord to Flatpak, make sure your 'xdg' or 'shell' 
# configs don't rely on the pacman binary path for Discord.
stow --adopt hypr
stow --adopt fish
stow --adopt xdg
stow --adopt shell

echo "✅ All dotfiles stowed! (Symlinks established.)"

# --- Automatic Git Cleanup ---
echo ""
echo "⚠️ Cleaning up adopted default config files in the Git repository..."

PACKAGES="hypr fish xdg shell" 

# This command checks out your saved content from the Git index, 
# overwriting the temporary default files that Stow adopted.
git checkout $PACKAGES

echo "✅ Git repository cleaned. Your symlinks now point to your desired content."
echo ""
echo "Restart your terminal or run: exec fish"
