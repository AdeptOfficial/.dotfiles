source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# Start SSH agent if not already running
if status is-interactive
    #keychain --quiet --eval id_ed25519 | source
end

# Initialize Starship prompt
starship init fish | source

# Add rice scripts and flatpak to PATH
set -gx PATH ~/.local/bin/rice $PATH /var/lib/flatpak/exports/bin
set -gx XDG_DATA_DIRS $XDG_DATA_DIRS:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share
