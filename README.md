# My Omarchy Dotfiles

Custom dotfiles for CachyOS + Omarchy using GNU Stow.

## Fresh Install
```bash
# Clone dotfiles
cd ~
git clone https://github.com/adeptofficial/.dotfiles.git

# Install dotfiles
cd .dotfiles
./stow-all.sh

# Restart terminal
exec fish

# Or restart Hyprland
hyprctl reload
```

## What This Includes

- **Hyprland**: All window manager configs
- **Fish**: Shell configuration with Starship init
- **Starship**: Custom prompt (user@hostname: path)
- **XDG**: Firefox as default browser

## Making Changes
```bash
# Edit configs in ~/.dotfiles/
nvim ~/.dotfiles/shell/.config/starship.toml

# Changes apply immediately (symlinked!)
# Just reload if needed
source ~/.config/fish/config.fish

# Commit changes
git add .
git commit -m "Update config"
git push
```

## Directory Structure
.dotfiles/
├── hypr/.config/hypr/       # Hyprland configs
├── fish/.config/fish/       # Fish shell config
├── shell/.config/           # Starship prompt
├── xdg/.config/             # Default applications
└── stow-all.sh              # Install script
