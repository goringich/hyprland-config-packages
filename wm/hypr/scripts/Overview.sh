#!/usr/bin/env bash
set -euo pipefail
# Desktop overview wrapper: use ags overview if available, else fall back to listing windows via wofi
if command -v ags >/dev/null 2>&1; then
  exec ags -t overview
fi
# fallback
if command -v wofi >/dev/null 2>&1; then
  # simple window list via hyprctl clients
  hyprctl clients -j | jq -r '.[] | "\(.address) \(.class) \(.title)"' | wofi --dmenu | awk '{print $1}' | while read -r addr; do
    hyprctl dispatch focuswindow address:$addr
  done
  exit 0
fi
echo "No overview method (ags or wofi) available" >&2
exit 1
