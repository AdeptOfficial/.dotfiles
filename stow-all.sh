#!/bin/bash
# Stow all dotfiles with dependency check and conflict resolution

# --- Function to check and install Stow ---
ensure_stow_installed() {
    # Check if 'stow' command is available
    if command -v stow &> /dev/null; then
        echo "✅ GNU Stow is already installed."
        return 0
    fi

    echo "⚠️ GNU Stow not found. Attempting to install..."

    # Check for common package managers and install
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y stow
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y stow
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm stow
    elif command -v brew &> /dev/null; then
        brew install stow
    else
        echo "❌ ERROR: Cannot find a supported package manager (apt, dnf, pacman, brew)."
        echo "Please install GNU Stow manually and re-run this script."
        exit 1
    fi

    # Final check after attempted installation
    if command -v stow &> /dev/null; then
        echo "✅ GNU Stow installed successfully."
    else
        echo "❌ ERROR: Stow installation failed. Please check the logs and install manually."
        exit 1
    fi
}
# ------------------------------------------

# 1. Run the dependency check
ensure_stow_installed

# 2. Proceed with stowing dotfiles using --adopt
echo "🔄 Stowing all dotfiles with conflict resolution (--adopt)..."

# Use --adopt to move any conflicting default files into the repo and create symlinks.
# This resolves the "existing target is not a symlink" error on new systems.
stow --adopt hypr
stow --adopt fish
stow --adopt xdg
stow --adopt shell

echo "✅ All dotfiles stowed! (Symlinks established.)"

# --- Automatic Git Cleanup ---
echo ""
echo "⚠️ Cleaning up adopted default config files in the Git repository..."

# List of packages that were stowed/adopted:
PACKAGES="hypr fish xdg shell stow-all.sh" 

# This command checks out your saved content from the Git index, 
# overwriting the temporary default files that Stow adopted.
git checkout $PACKAGES

echo "✅ Git repository cleaned. Your symlinks now point to your desired content."
echo ""
echo "Restart your terminal or run: exec fish"
