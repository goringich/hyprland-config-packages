#!/usr/bin/env bash
# ClipHistoryMenu.sh - open clipboard history and copy selection back to clipboard
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

if ! have cliphist; then
  echo "[cliphist] cliphist not installed" >&2
  exit 1
fi

MENU="rofi"
if have rofi; then MENU="rofi"; elif have wofi; then MENU="wofi"; else MENU="stdin"; fi

case "$MENU" in
  rofi)
    SEL=$(cliphist list | rofi -dmenu -p "Clipboard" -theme-str 'window { width: 60%; }') || exit 0
    ;;
  wofi)
    SEL=$(cliphist list | wofi --dmenu --prompt "Clipboard") || exit 0
    ;;
  stdin)
    echo "[cliphist] No rofi/wofi; showing first entry in stdout" >&2
    SEL=$(cliphist list | head -n 1)
    ;;
esac

if [ -n "$SEL" ]; then
  echo "$SEL" | cliphist decode | wl-copy
fi