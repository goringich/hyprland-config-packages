#!/usr/bin/env bash
# Unified terminal launcher for Hyprland scripts
# Usage: RunInTerminal.sh <terminal> <command> [args...]
# Supports: alacritty, kitty, foot, konsole (fallback to alacritty)
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <terminal> <command> [args...]" >&2
  exit 1
fi

term="$1"; shift
cmd=("$@")

# Optional custom title derived from first command word
TITLE="${cmd[0]##*/}"

case "$term" in
  alacritty)
    exec alacritty --title "$TITLE" -e "${cmd[@]}" ;;
  kitty)
    exec kitty --title "$TITLE" "${cmd[@]}" ;;
  foot)
    exec foot --title "$TITLE" "${cmd[@]}" ;;
  konsole)
    exec konsole -e "${cmd[@]}" ;;
  *)
    if command -v "$term" >/dev/null 2>&1; then
      exec "$term" "${cmd[@]}"
    else
      exec alacritty --title "$TITLE" -e "${cmd[@]}"
    fi
    ;;
 esac
