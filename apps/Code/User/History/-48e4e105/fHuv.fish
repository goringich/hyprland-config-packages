# Add ~/.config/bin to PATH if not already
if not contains -- $HOME/.config/bin $PATH
    set -gx PATH $HOME/.config/bin $PATH
end

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
    # Commands to run in interactive sessions can go here
end
