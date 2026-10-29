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

# Add rice scripts to PATH
set -gx PATH ~/.local/bin/rice $PATH

# Source machine-specific config (gitignored)
if test -f ~/.config/fish/config.local.fish
    source ~/.config/fish/config.local.fish
end

