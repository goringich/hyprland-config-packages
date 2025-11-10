#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Not inside a git repo" >&2
  exit 1
fi
cd "$repo_root"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# 1) Ensure SSH key exists
KEY="$HOME/.ssh/id_ed25519"
if [[ ! -f "$KEY" ]]; then
  echo "[ssh] generating SSH key (ed25519)"
  ssh-keygen -t ed25519 -N "" -C "$(whoami)@$(hostname)" -f "$KEY" >/dev/null
fi
chmod 600 "$KEY" "$KEY.pub"

# 2) Ensure ssh-agent has the key loaded
if ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi
ssh-add "$KEY" >/dev/null 2>&1 || true

# 3) Configure SSH over 443 for GitHub
CFG="$HOME/.ssh/config"
if ! grep -q "ssh.github.com" "$CFG" 2>/dev/null; then
  {
    echo "Host github.com"
    echo "  HostName ssh.github.com"
    echo "  Port 443"
    echo "  User git"
    echo "  IdentityFile $KEY"
    echo "  IdentitiesOnly yes"
    echo "  StrictHostKeyChecking accept-new"
    echo
  } >> "$CFG"
fi
chmod 600 "$CFG"

# 4) Set fetch via HTTPS (always works), push via SSH (requires key on GitHub)
HTTPS_URL="https://github.com/goringich/hyprland-config-packages.git"
SSH_URL="git@github.com:goringich/hyprland-config-packages.git"

git remote set-url origin "$HTTPS_URL"
git remote set-url --push origin "$SSH_URL"

# 5) Test fetch (HTTPS)
if timeout 15s git fetch -v origin >/dev/null 2>&1; then
  echo "[git] fetch over HTTPS OK"
else
  echo "[git] fetch over HTTPS FAILED" >&2
fi

# 6) Optional: upload key with gh if available and authed
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    title="$(hostname)-$(date +%Y%m%d-%H%M%S)"
    if ! gh ssh-key list | grep -q "$(cat "$KEY.pub" | cut -d' ' -f2)"; then
      gh ssh-key add "$KEY.pub" -t "$title" >/dev/null && echo "[gh] public key uploaded"
    fi
  else
    echo "[gh] gh is installed but not authenticated; skipping key upload"
  fi
else
  echo "[ssh] Add this public key to GitHub (Settings → SSH keys):"
  echo
  cat "$KEY.pub"
  echo
fi

# 7) Quick SSH test (port 443)
if timeout 8s ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com >/dev/null 2>&1; then
  echo "[ssh] SSH to GitHub reachable"
else
  echo "[ssh] SSH to GitHub not yet authorized (likely key not added to GitHub)" >&2
fi
