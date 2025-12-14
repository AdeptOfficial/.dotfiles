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
alias update="sudo pacman -Syu"
alias clean="sudo pacman -Sc"

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
