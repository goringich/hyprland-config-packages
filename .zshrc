# Choose oh-my-zsh install location (user clone or system package)
if [[ -d "$HOME/.oh-my-zsh" ]]; then
    export ZSH="$HOME/.oh-my-zsh"
else
    export ZSH="/usr/share/oh-my-zsh"
fi

ZSH_THEME="blinks"

plugins=(
    git
    archlinux
)

source "$ZSH/oh-my-zsh.sh"

# Load custom shims/aliases for modern CLI replacements
if [[ -f "$HOME/.config/shell/shims.sh" ]]; then
    source "$HOME/.config/shell/shims.sh"
fi

# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Display Pokemon-colorscripts
# Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
if command -v pokemon-colorscripts >/dev/null 2>&1 && command -v fastfetch >/dev/null 2>&1; then
    pokemon-colorscripts --no-title -s -r |
        fastfetch -c "$HOME/.config/fastfetch/config-pokemon.jsonc" \
                            --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
fi

# fastfetch. Will be disabled if above colorscript was chosen to install
#fastfetch -c $HOME/.config/fastfetch/config-compact.jsonc

# Set-up icons for files/directories in terminal using lsd
if command -v lsd >/dev/null 2>&1; then
    alias ls='lsd'
    alias l='ls -l'
    alias la='ls -a'
    alias lla='ls -la'
    alias lt='ls --tree'
fi

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
alias telegram-desktop="QT_QPA_PLATFORM=xcb /usr/bin/telegram-desktop"
export PATH="$HOME/.local/bin:$PATH"

# === SSH Agent Configuration ===
# SSH Agent environment file
SSH_AGENT_ENV_FILE="$HOME/.ssh-agent-env"

# Function to start SSH agent
start_ssh_agent() {
    echo "Starting SSH agent..."
    ssh-agent -s > "$SSH_AGENT_ENV_FILE"
    source "$SSH_AGENT_ENV_FILE" > /dev/null
}

# Function to check if SSH agent is running
is_ssh_agent_running() {
    if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
        ssh-add -l >/dev/null 2>&1
        return $?
    fi
    return 1
}

# Load SSH agent environment if it exists
if [ -f "$SSH_AGENT_ENV_FILE" ]; then
    source "$SSH_AGENT_ENV_FILE" > /dev/null
fi

# Start SSH agent if not running
if ! is_ssh_agent_running; then
    start_ssh_agent
fi

# Auto-load SSH keys (only if agent has no keys loaded)
if ssh-add -l >/dev/null 2>&1; then
    # Agent has keys loaded
    :
else
    # No keys loaded, add them silently
    for key in $HOME/.ssh/id_*(N) $HOME/.ssh/*-key(N); do
        if [ -f "$key" ] && [ "${key##*.}" != "pub" ]; then
            ssh-add "$key" 2>/dev/null
        fi
    done
fi

# === Zoxide Configuration ===
if command -v zoxide >/dev/null 2>&1; then
    # Initialize zoxide (smart cd replacement)
    eval "$(zoxide init zsh)"

    # Aliases for zoxide
    alias cd='z'
    alias cdi='zi'  # Interactive selection
    alias ..='z ..'
    alias ...='z ../..'
    alias ....='z ../../..'
fi

if [[ -f "$HOME/.config/broot/launcher/bash/br" ]]; then
    source "$HOME/.config/broot/launcher/bash/br"
fi
# autosuggestions (показывает серым подсказки по истории)
if [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# syntax highlighting (подсвечивает команды как в IDE)
if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Powerlevel10k theme configuration (optional)
if [[ "$ZSH_THEME" == "powerlevel10k/powerlevel10k" ]]; then
    if [[ -f "$HOME/.p10k.zsh" ]]; then
        source "$HOME/.p10k.zsh"
    elif [[ -f "$HOME/.config/p10k.zsh" ]]; then
        source "$HOME/.config/p10k.zsh"
    fi
fi