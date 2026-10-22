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

# Package lists live in stow-packages.conf (shared with install.sh)
source "$(dirname "$0")/stow-packages.conf"
PACKAGES="$STOW_PACKAGES"
[[ "${1:-}" == "desktop" ]] && PACKAGES="$PACKAGES $STOW_PACKAGES_DESKTOP"
for pkg in $PACKAGES; do
    stow --adopt "$pkg"
done

echo "✅ All dotfiles stowed! (Symlinks established.)"

# --- Automatic Git Cleanup ---
echo ""
echo "⚠️ Cleaning up adopted default config files in the Git repository..."


# This command checks out your saved content from the Git index, 
# overwriting the temporary default files that Stow adopted.
git checkout $PACKAGES

echo "✅ Git repository cleaned. Your symlinks now point to your desired content."
echo ""
echo "Restart your terminal or run: exec fish"
