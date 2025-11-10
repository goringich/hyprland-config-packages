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
PRIMARY_KEY="$HOME/.ssh/github"
FALLBACK_KEY="$HOME/.ssh/id_ed25519"
if [[ -f "$PRIMARY_KEY" ]]; then
  KEY="$PRIMARY_KEY"
else
  KEY="$FALLBACK_KEY"
fi
if [[ ! -f "$KEY" ]]; then
  echo "[ssh] no existing key named github or id_ed25519; generating new ed25519" 
  ssh-keygen -t ed25519 -N "" -C "$(whoami)@$(hostname)" -f "$FALLBACK_KEY" >/dev/null
  KEY="$FALLBACK_KEY"
fi
chmod 600 "$KEY" "$KEY.pub"

# 2) Ensure ssh-agent has the key loaded
if ! ssh-add -l >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
fi
# Remove previously loaded identities to avoid confusion
ssh-add -D >/dev/null 2>&1 || true
ssh-add "$KEY" >/dev/null 2>&1 || true

# 3) Configure SSH over 443 for GitHub using Include (no awk parsing)
CFG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh/conf.d"
INC_LINE='Include ~/.ssh/conf.d/*.conf'
grep -qE "^$INC_LINE" "$CFG" 2>/dev/null || { echo "$INC_LINE" >> "$CFG"; }
GH_CONF="$HOME/.ssh/conf.d/github-443.conf"
cat > "$GH_CONF" <<EOF
Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile $KEY
  IdentitiesOnly yes
  AddKeysToAgent yes
  StrictHostKeyChecking accept-new

EOF
chmod 600 "$GH_CONF"
chmod 600 "$CFG" 2>/dev/null || true

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
if timeout 10s ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 | grep -qi "success"; then
  echo "[ssh] SSH authenticated"
else
  echo "[ssh] SSH handshake done (may show warning if key not authorized yet)" 
fi
