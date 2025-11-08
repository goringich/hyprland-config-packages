#!/usr/bin/env bash
# Ensure a desired branch exists locally & remotely; create from main/master fallback; then pull.
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[sync] Not inside a git repo" >&2
  exit 1
fi

DESIRED="${1:-master}" # default to master if not provided
CURRENT="$(git rev-parse --abbrev-ref HEAD)"

# Determine base branch preference order
BASE=""
for candidate in main master; do
  if git show-ref --verify --quiet "refs/heads/$candidate"; then
    BASE=$candidate
    break
  fi
done
[ -z "$BASE" ] && BASE="$CURRENT"

# Create desired branch locally if missing
if ! git show-ref --verify --quiet "refs/heads/$DESIRED"; then
  echo "[sync] Creating local branch '$DESIRED' from '$BASE'"
  git switch -c "$DESIRED" "$BASE"
else
  if [ "$CURRENT" != "$DESIRED" ]; then
    git switch "$DESIRED"
  fi
fi

# Push branch upstream if remote head missing (timeout fallback)
if ! git ls-remote --exit-code --heads origin "$DESIRED" >/dev/null 2>&1; then
  echo "[sync] Remote branch '$DESIRED' missing; pushing"
  timeout 20s git push -u origin "$DESIRED" || echo "[sync] Push timed out or failed (will continue)"
fi

# Final safe pull with timeout
echo "[sync] Pulling updates for '$DESIRED'"
timeout 25s git pull --ff-only || echo "[sync] Pull timed out or failed"

echo "[sync] Done (branch: $(git rev-parse --abbrev-ref HEAD))"