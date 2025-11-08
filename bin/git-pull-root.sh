#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Not inside a git repo" >&2
  exit 1
fi
cd "$repo_root"

# Ensure we don't hang forever
TMO="timeout 20s"

# If upstream set, use it; else try origin/pc then origin/master
current_branch="$(git rev-parse --abbrev-ref HEAD)"
upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || true)"

if [[ -n "$upstream_ref" ]]; then
  $TMO git fetch -v --prune
  exec $TMO git pull --ff-only
fi

# No upstream: pick a sensible default
if git ls-remote --exit-code --heads origin pc >/dev/null 2>&1; then
  $TMO git fetch -v --prune origin pc
  exec $TMO git pull --ff-only origin pc
else
  $TMO git fetch -v --prune origin master
  exec $TMO git pull --ff-only origin master
fi
