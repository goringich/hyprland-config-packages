#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Not inside a git repo" >&2
  exit 1
fi
cd "$repo_root"

current_url="$(git remote get-url origin 2>/dev/null || true)"
if [[ -z "$current_url" ]]; then
  echo "No origin remote configured" >&2
  exit 1
fi

echo "[fix] origin: $current_url"

# Try SSH timed ls-remote (8s)
if [[ "$current_url" =~ ^git@github.com: ]]; then
  echo "[fix] testing SSH with timeout..."
  if timeout 8s env GIT_SSH_COMMAND='ssh -4 -o ConnectTimeout=5 -o BatchMode=yes' git ls-remote origin >/dev/null 2>&1; then
    echo "[fix] SSH works; leaving remote unchanged"
    exit 0
  else
    echo "[fix] SSH timed out or failed. Switching to HTTPS."
    https_url="https://github.com/${current_url#git@github.com:}"
    git remote set-url origin "$https_url"
    echo "[fix] origin -> $https_url"
    # Test fetch
    if timeout 12s git fetch -v origin >/dev/null 2>&1; then
      echo "[fix] fetch over HTTPS OK"
      exit 0
    else
      echo "[fix] fetch over HTTPS failed" >&2
      exit 2
    fi
  fi
else
  echo "[fix] origin is not SSH; trying fetch with timeout..."
  if timeout 12s git fetch -v origin >/dev/null 2>&1; then
    echo "[fix] fetch OK"
    exit 0
  else
    echo "[fix] fetch failed" >&2
    exit 3
  fi
fi
