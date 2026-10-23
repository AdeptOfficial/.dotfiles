# === Docker Aliases ===
alias dps="docker ps"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcr="docker compose restart"
alias dlog="docker compose logs -f"

# === Home Assistant ===
alias ha="docker exec -it home-assistant"
alias ha-restart="docker restart home-assistant"
alias ha-logs="docker logs -f home-assistant"

# === Ollama ===
alias ollama-gpu="docker exec -it ollama nvidia-smi"
alias ollama-logs="docker logs -f ollama"
alias ollama-restart="docker restart ollama"

# === System ===
alias update="syna-update"        # guided update: pre-checks, research, install, post-check
alias clean="sudo paccache -r"     # trim package cache, keep 3 versions (syna-update-undo needs them)
alias afk="syna-dream"           # AFK screensaver: syna is dreaming

# === Navigation ===
alias ..="cd .."
alias ...="cd ../.."
alias dots="cd ~/.dotfiles"

# === Git ===
alias gs="git status"
alias ga="git add"
alias gc="git commit -m"
alias gp="git push"
alias gl="git pull"
