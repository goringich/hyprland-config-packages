#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -x "$REPO_ROOT/bin/sync-dotfiles.sh" ]]; then
  "$REPO_ROOT/bin/sync-dotfiles.sh"
else
  echo "sync-dotfiles.sh not found/executable" >&2
  exit 1
fi

# Show quick summary
set +e
CHANGES=$(git status --porcelain)
set -e
if [[ -n "$CHANGES" ]]; then
  echo
  echo "Repo updated. Review changes via 'git status' and commit:"
  echo "  git add -A && git commit -m \"chore: refresh dotfiles\""
else
  echo "No changes detected."
fi
