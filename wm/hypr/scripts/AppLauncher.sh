#!/usr/bin/env bash
set -euo pipefail
# Unified app launcher: rofi preferred, fall back to wofi
if command -v rofi >/dev/null 2>&1; then
  exec rofi -show drun -modi drun,filebrowser,run,window
elif command -v wofi >/dev/null 2>&1; then
  exec wofi --show drun
else
  echo "No launcher (rofi/wofi) installed" >&2
  exit 1
fi
