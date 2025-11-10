#!/usr/bin/env bash
# LayoutNotify.sh - show current keyboard layout via notify-send or simple echo
set -euo pipefail
CURRENT=$(hyprctl devices -j | jq -r '.keyboards[0].active_keymap // "unknown"' 2>/dev/null || echo unknown)
if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "Keyboard" "Layout: $CURRENT"
else
  echo "Layout: $CURRENT"
fi