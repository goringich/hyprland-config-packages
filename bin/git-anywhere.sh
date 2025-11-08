#!/usr/bin/env bash
set -euo pipefail
# Usage: git-anywhere.sh <repo-name or URL> [branch]
# Pull (or clone if absent) with timeouts, initializes empty remote if needed.

TIME_FETCH="timeout 15s"
TIME_PULL="timeout 20s"

repo_arg="${1:-}"
branch_arg="${2:-}"
if [[ -z "$repo_arg" ]]; then
  echo "Usage: git-anywhere.sh <repo-name or URL> [branch]" >&2
  exit 1
fi

# Normalize input to full SSH URL if shorthand
if [[ "$repo_arg" != *:*/* && "$repo_arg" != git@github.com:* ]]; then
  # treat as owner/repo or just repo under your username
  if [[ "$repo_arg" == */* ]]; then
    repo_url="git@github.com:${repo_arg}.git"
  else
    repo_url="git@github.com:goringich/${repo_arg}.git"
  fi
else
  repo_url="$repo_arg"
fi

repo_name="$(basename -s .git "$repo_url")"

# Clone if directory missing
if [[ ! -d "$repo_name/.git" ]]; then
  echo "[anywhere] cloning $repo_url";
  if ! $TIME_FETCH git clone --depth=1 "$repo_url" "$repo_name" 2>/dev/null; then
    echo "[anywhere] clone failed (maybe private or empty). Attempting full clone." >&2
    if ! $TIME_FETCH git clone "$repo_url" "$repo_name"; then
      echo "[anywhere] clone failed permanently" >&2
      exit 2
    fi
  fi
fi

cd "$repo_name"

# Determine branch
if [[ -n "$branch_arg" ]]; then
  target_branch="$branch_arg"
else
  # prefer main then master
  if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
    target_branch="main"
  elif git ls-remote --exit-code --heads origin master >/dev/null 2>&1; then
    target_branch="master"
  else
    target_branch="main" # will create if empty remote
  fi
fi

# If repo has no commits locally
if ! git rev-parse HEAD >/dev/null 2>&1; then
  echo "[anywhere] local repo empty; checking remote heads";
  if ! git ls-remote --exit-code --heads origin >/dev/null 2>&1; then
    echo "[anywhere] remote appears empty; creating first commit on $target_branch";
    git switch -c "$target_branch" || git checkout -b "$target_branch"
    echo "# Initial commit $(date -u +%Y-%m-%dT%H:%M:%SZ)" > README.md
    git add README.md
    git commit -m "chore: initial commit"
    if ! $TIME_PULL git push -u origin "$target_branch"; then
      echo "[anywhere] push failed; remote may be private or SSH key not added" >&2
      exit 3
    fi
  else
    echo "[anywhere] remote has heads; fetching";
    $TIME_FETCH git fetch -v --prune || echo "[anywhere] fetch timed out" >&2
    git switch "$target_branch" 2>/dev/null || git checkout -b "$target_branch" origin/"$target_branch" || true
    $TIME_PULL git pull --ff-only origin "$target_branch" || echo "[anywhere] pull failed (divergence?)" >&2
  fi
else
  echo "[anywhere] existing repo; safe fetch/pull";
  $TIME_FETCH git fetch -v --prune || echo "[anywhere] fetch timeout" >&2
  git switch "$target_branch" 2>/dev/null || git checkout "$target_branch" || true
  $TIME_PULL git pull --ff-only origin "$target_branch" || echo "[anywhere] pull failed" >&2
fi

echo "[anywhere] done: $(pwd) on branch $(git rev-parse --abbrev-ref HEAD)"
