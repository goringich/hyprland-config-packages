#!/usr/bin/env bash
set -euo pipefail

ARCHIVE="$HOME/.config/.archive-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE"

MOVE_LIST=(
  KDE
  kde.org
  kdedefaults
  i3
)

for d in "${MOVE_LIST[@]}"; do
  if [[ -e "$HOME/.config/$d" ]]; then
    echo "[cleanup] Moving $d -> $ARCHIVE/$d"
    mv "$HOME/.config/$d" "$ARCHIVE/" || true
  fi
done

echo "Done. You can restore any directory from $ARCHIVE if needed."
