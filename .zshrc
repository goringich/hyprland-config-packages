# --- oh-my-zsh + powerlevel10k profile ---
if [[ -z "${ZSH:-}" ]]; then
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    export ZSH="$HOME/.oh-my-zsh"
  else
    export ZSH="/usr/share/oh-my-zsh"
  fi
fi
if [[ -z "${ZSH_CUSTOM:-}" ]]; then
  export ZSH_CUSTOM="$HOME/.config/oh-my-zsh/custom"
fi

export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
ZSH_THEME="powerlevel10k/powerlevel10k"

if ! typeset -p plugins >/dev/null 2>&1; then
  plugins=()
fi
typeset -Ua plugins
for _p in git archlinux fzf extract; do
  [[ " ${plugins[*]} " == *" ${_p} "* ]] || plugins+=("${_p}")
done
unset _p

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# --- extra tooling and environment ---
if [[ -f "$HOME/.config/shell/shims.sh" ]]; then
  source "$HOME/.config/shell/shims.sh"
fi

# CachyOS defaults
DISABLE_MAGIC_FUNCTIONS="true"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"
export HISTCONTROL=ignoreboth
export HISTIGNORE="&:[bf]g:c:clear:history:exit:q:pwd:* --help"
export LESS_TERMCAP_md="$(tput bold 2> /dev/null; tput setaf 2 2> /dev/null)"
export LESS_TERMCAP_me="$(tput sgr0 2> /dev/null)"
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

# Aliases from CachyOS profile
alias make="make -j$(nproc)"
alias ninja="ninja -j$(nproc)"
alias n="ninja"
alias c="clear"
alias rmpkg="sudo pacman -Rsn"
alias cleanch="sudo pacman -Scc"
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias update="sudo pacman -Syu"
alias apt="man pacman"
alias apt-get="man pacman"
alias please="sudo"
alias tb="nc termbin.com 9999"
alias cleanup="sudo pacman -Rsn $(pacman -Qtdq)"
alias jctl="journalctl -p 3 -xb"
alias rip="expac --timefmt='%Y-%m-%d %T' '%l\t%n %v' | sort | tail -200 | nl"

if command -v pokemon-colorscripts >/dev/null 2>&1 && command -v fastfetch >/dev/null 2>&1; then
  pokemon-colorscripts --no-title -s -r |
    fastfetch -c "$HOME/.config/fastfetch/config-pokemon.jsonc" \
      --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
fi

if command -v lsd >/dev/null 2>&1; then
  alias ls='lsd'
  alias l='ls -l'
  alias la='ls -a'
  alias lla='ls -la'
  alias lt='ls --tree'
fi

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
alias telegram-desktop='QT_QPA_PLATFORM=xcb /usr/bin/telegram-desktop'
export PATH="$HOME/.local/bin:$PATH"

SSH_AGENT_ENV_FILE="$HOME/.ssh-agent-env"
start_ssh_agent() {
  echo "Starting SSH agent..."
  ssh-agent -s > "$SSH_AGENT_ENV_FILE"
  source "$SSH_AGENT_ENV_FILE" > /dev/null
}

is_ssh_agent_running() {
  if [[ -n "$SSH_AUTH_SOCK" && -S "$SSH_AUTH_SOCK" ]]; then
    ssh-add -l >/dev/null 2>&1
    return $?
  fi
  return 1
}

if [[ -f "$SSH_AGENT_ENV_FILE" ]]; then
  source "$SSH_AGENT_ENV_FILE" > /dev/null
fi

if ! is_ssh_agent_running; then
  start_ssh_agent
fi

if ! ssh-add -l >/dev/null 2>&1; then
  for key in $HOME/.ssh/id_*(N) $HOME/.ssh/*-key(N); do
    if [[ -f "$key" && "${key##*.}" != "pub" ]]; then
      ssh-add "$key" 2>/dev/null
    fi
  done
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd='z'
  alias cdi='zi'
  alias ..='z ..'
  alias ...='z ../..'
  alias ....='z ../../..'
fi

if [[ -f "$HOME/.config/broot/launcher/bash/br" ]]; then
  source "$HOME/.config/broot/launcher/bash/br"
fi

if [[ -r /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
fi
if [[ -r /usr/share/fzf/completion.zsh ]]; then
  source /usr/share/fzf/completion.zsh
fi
if [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
if [[ -r /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
fi
if [[ -r /usr/share/doc/pkgfile/command-not-found.zsh ]]; then
  source /usr/share/doc/pkgfile/command-not-found.zsh
fi

export FZF_BASE=/usr/share/fzf

bindkey -v
export KEYTIMEOUT=1
setopt TRANSIENT_RPROMPT
autoload -Uz colors && colors
ZLE_RPROMPT_INDENT=0
PROMPT_EOL_MARK=''

if [[ -f "$HOME/.config/p10k.zsh" ]]; then
  source "$HOME/.config/p10k.zsh"
fi
# --- end oh-my-zsh + powerlevel10k profile ---
