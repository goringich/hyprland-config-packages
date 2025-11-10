#!/usr/bin/env bash
# Ensure SSH to GitHub uses port 443 and the agent/socket are set up.
set -euo pipefail

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

KEY="$HOME/.ssh/github"
[ -f "$KEY" ] || KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$KEY" ]; then
  echo "[ssh] Generating new ed25519 key at $HOME/.ssh/id_ed25519"
  ssh-keygen -t ed25519 -N "" -C "$(whoami)@$(hostname)" -f "$HOME/.ssh/id_ed25519" >/dev/null
  KEY="$HOME/.ssh/id_ed25519"
fi
chmod 600 "$KEY" "$KEY.pub"

CFG="$HOME/.ssh/config"
# Replace or append minimal github.com block
awk -v key="$KEY" 'BEGIN{seen=0}
  /^Host github\.com$/ { 
    print; getline; 
    while ($0 ~ /^ /) { getline } 
    print "  HostName ssh.github.com"; 
    print "  Port 443"; 
    print "  User git"; 
    print "  IdentityFile " key; 
    print "  IdentitiesOnly yes"; 
    print "  AddKeysToAgent yes"; 
    print "  StrictHostKeyChecking accept-new"; 
    print ""; 
    seen=1; 
  }
  { print } 
  END { if (!seen) { 
    print "Host github.com"; 
    print "  HostName ssh.github.com"; 
    print "  Port 443"; 
    print "  User git"; 
    print "  IdentityFile " key; 
    print "  IdentitiesOnly yes"; 
    print "  AddKeysToAgent yes"; 
    print "  StrictHostKeyChecking accept-new"; 
    print ""; 
  }}' "$CFG" 2>/dev/null | sed '/^$/N;/^\n$/D' > "$CFG.tmp" || true

if [ -s "$CFG.tmp" ]; then
  mv "$CFG.tmp" "$CFG"
else
  cat > "$CFG" <<EOF
Host github.com
  HostName ssh.github.com
  Port 443
  User git
  IdentityFile $KEY
  IdentitiesOnly yes
  AddKeysToAgent yes
  StrictHostKeyChecking accept-new

EOF
fi
chmod 600 "$CFG"

# Start/enable user ssh-agent via systemd if available
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user enable --now ssh-agent.service >/dev/null 2>&1 || true
fi

# Export SSH_AUTH_SOCK for current shell if systemd socket exists
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/ssh-agent.socket" ]; then
  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
fi

# Load the key
ssh-add -l >/dev/null 2>&1 || ssh-add "$KEY" >/dev/null 2>&1 || true

# Smoke test SSH on port 443 (no auth required)
if timeout 8s ssh -T -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>&1 | grep -qi "success"; then
  echo "[ssh] SSH authenticated to GitHub"
else
  echo "[ssh] SSH handshake attempted (if key not added to GitHub, you may see a warning)"
fi

# Show public key for convenience
echo "[ssh] Your public key:" && echo && cat "$KEY.pub" && echo