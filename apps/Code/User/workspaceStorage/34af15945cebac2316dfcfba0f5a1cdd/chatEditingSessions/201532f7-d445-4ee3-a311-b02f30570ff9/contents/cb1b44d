#!/usr/bin/env bash
# ScreenshotCopy.sh - capture screen (full or area) and copy to clipboard (Wayland)
set -euo pipefail

MODE="${1:-full}" # full | area | window
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$OUT_DIR"
FILE="$OUT_DIR/screenshot-$TS.png"

have() { command -v "$1" >/dev/null 2>&1; }

if ! have grim; then
  echo "[screenshot] grim not installed" >&2; exit 1; fi
if ! have wl-copy; then
  echo "[screenshot] wl-clipboard (wl-copy) not installed" >&2; exit 1; fi

case "$MODE" in
  full)
    grim "$FILE" ;;
  area)
    if have slurp; then
      grim -g "$(slurp)" "$FILE"
    else
      echo "[screenshot] slurp missing; falling back to full" >&2
      grim "$FILE"
    fi
    ;;
  window)
    # Attempt active window region via hyprctl (approximate)
    if have hyprctl; then
      GEOM=$(hyprctl clients -j | jq -r '.[] | select(.focused==true) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
      if [ -n "$GEOM" ]; then
        grim -g "$GEOM" "$FILE"
      else
        grim "$FILE"
      fi
    else
      grim "$FILE"
    fi
    ;;
  *) echo "[screenshot] unknown mode: $MODE" >&2; exit 2;;
esac

# Copy to clipboard
wl-copy < "$FILE" || true
echo "[screenshot] Saved to $FILE and copied to clipboard"