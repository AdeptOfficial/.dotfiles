# My Omarchy Dotfiles

Custom dotfiles for CachyOS + Omarchy using GNU Stow.

## Features

- **Hyprland**: Window manager configuration with custom keybindings
- **Starship**: Custom prompt (`user@hostname: path`)
- **Fish Shell**: Shell configuration with custom aliases
- **Firefox**: Set as default browser
- **Organized**: Each component in its own stow package

## Fresh Install
````bash
# Clone dotfiles
cd ~
git clone https://github.com/adeptofficial/.dotfiles.git

# Install all dotfiles
cd .dotfiles
./stow-all.sh

# Restart terminal
exec fish

# Reload Hyprland
hyprctl reload
````

## Custom Aliases

All aliases are in `fish/.config/fish/conf.d/aliases.fish`:

### Docker
- `dps` - docker ps
- `dcu` - docker compose up -d
- `dcd` - docker compose down
- `dcr` - docker compose restart
- `dlog` - docker compose logs -f

### Home Assistant
- `ha` - docker exec into home-assistant
- `ha-restart` - restart home-assistant container
- `ha-logs` - follow home-assistant logs

### Ollama
- `ollama-gpu` - check GPU status
- `ollama-logs` - follow ollama logs
- `ollama-restart` - restart ollama container

### System
- `update` - sudo pacman -Syu
- `clean` - sudo pacman -Sc

### Navigation
- `..` - cd ..
- `...` - cd ../..
- `dots` - cd ~/.dotfiles

### Git
- `gs` - git status
- `ga` - git add
- `gc` - git commit -m
- `gp` - git push
- `gl` - git pull

## Making Changes
````bash
# Edit any config in ~/.dotfiles/
nvim ~/.dotfiles/shell/.config/starship.toml
nvim ~/.dotfiles/fish/.config/fish/conf.d/aliases.fish
nvim ~/.dotfiles/hypr/.config/hypr/bindings.conf

# Changes apply immediately (files are symlinked!)
# For Fish changes, restart terminal:
exec fish

# Commit changes
cd ~/.dotfiles
git add .
git commit -m "Update config"
git push
````

## Directory Structure
````
.dotfiles/
├── hypr/.config/hypr/          # Hyprland configs
│   ├── hyprland.conf
│   ├── bindings.conf
│   ├── monitors.conf
│   └── ...
├── fish/.config/fish/          # Fish shell
│   ├── config.fish
│   └── conf.d/
│       └── aliases.fish        # Custom aliases
├── shell/.config/
│   └── starship.toml           # Starship prompt config
├── xdg/.config/
│   └── mimeapps.list           # Default applications (Firefox)
├── stow-all.sh                 # Install script
├── .gitignore
└── README.md
````

## Customization Examples

### Change Prompt Style
Edit `shell/.config/starship.toml`:
````toml
[directory]
format = ": [$path]($style) "  # Change separator
style = "bold cyan"             # Change color
````

### Add New Alias
Edit `fish/.config/fish/conf.d/aliases.fish`:
````fish
alias myalias="my command"
````

Then restart terminal: `exec fish`

### Add Hyprland Keybinding
Edit `hypr/.config/hypr/bindings.conf`:
````
bind = SUPER, B, exec, firefox
````

Then reload: `hyprctl reload`

## Backup

All configs are version controlled with git. To restore:
````bash
cd ~/.dotfiles
git checkout <commit-hash>
./stow-all.sh
```
