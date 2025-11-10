# Add ~/.config/bin to PATH if not already
if not contains -- $HOME/.config/bin $PATH
    set -gx PATH $HOME/.config/bin $PATH
end

# Prefer systemd-managed ssh-agent socket if it exists
if test -n "$XDG_RUNTIME_DIR" -a -S "$XDG_RUNTIME_DIR/ssh-agent.socket"
    set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
end

# Fallback: start ssh-agent only if no socket detected
if not set -q SSH_AUTH_SOCK
    if type -q ssh-agent
        eval (ssh-agent -c) >/dev/null
    end
end

# Load GitHub key (or any existing key) if none loaded
if type -q ssh-add
    ssh-add -l >/dev/null 2>&1; or begin
        if test -f ~/.ssh/github
            ssh-add ~/.ssh/github >/dev/null 2>&1; or true
        else if test -f ~/.ssh/id_ed25519
            ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1; or true
        end
    end
end

# Git sane defaults with low-speed/timeout to avoid hangs
set -gx GIT_HTTP_LOW_SPEED_LIMIT 1000
set -gx GIT_HTTP_LOW_SPEED_TIME 10

# Short git helpers with timeouts
function gpf --description 'Safe git pull from repo root'
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        ~/.config/bin/git-pull-root.sh
    else
        echo 'Not in a git repo' >&2
        return 1
    end
end

function gpr --description 'Safe git fetch/pull current branch (timeout)'
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l upstream (git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null)
        if test -n "$upstream"
            timeout 12s git fetch -v --prune; and timeout 15s git pull --ff-only
        else
            echo 'No upstream; using git-pull-root.sh fallback'
            ~/.config/bin/git-pull-root.sh
        end
    else
        echo 'Not in a git repo' >&2
        return 1
    end
end

function gpo --description 'Push current branch (timeout)' 
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l branch (git rev-parse --abbrev-ref HEAD)
        if test "$branch" = 'HEAD'
            echo 'Detached HEAD; abort push' >&2
            return 1
        end
        timeout 15s git push origin $branch
    else
        echo 'Not in a git repo' >&2
        return 1
    end
end
if status is-interactive
    # Initialize starship prompt (left + right system info)
    if command -v starship >/dev/null 2>&1
        starship init fish | source
    end
    # CachyOS banner (optional; disable by commenting next line)
    if test -x $HOME/.config/bin/show-cachyos-banner.sh
        $HOME/.config/bin/show-cachyos-banner.sh
    end
end
