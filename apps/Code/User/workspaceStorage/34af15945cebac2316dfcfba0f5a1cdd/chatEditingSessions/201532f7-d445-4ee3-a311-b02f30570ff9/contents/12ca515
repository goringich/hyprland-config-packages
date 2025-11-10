#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$HOME/Рабочий стол/obsidian"
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "[obsidian] Repo not found at $REPO_DIR" >&2
  exit 1
fi
cd "$REPO_DIR"
~/.config/bin/git-sync-branch.sh master
