#!/bin/bash
# Stow all dotfiles

echo "🔄 Stowing all dotfiles..."

# Stow each package
stow -R hypr
stow -R fish  
stow -R xdg
stow -R shell

echo "✅ All dotfiles stowed!"
echo ""
echo "Restart your terminal or run: exec fish"
