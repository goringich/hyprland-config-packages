#!/usr/bin/env bash
set -euo pipefail
# Start common components only if installed
maybe_start() {
  local name="$1"; shift || true
  if command -v "$name" >/dev/null 2>&1; then
    ("$name" "$@" &>/dev/null &)
  fi
}

# swww daemon
if command -v swww >/dev/null 2>&1; then
  if ! pgrep -x swww-daemon >/dev/null 2>&1; then
    (swww-daemon --format xrgb &)
  fi
fi

maybe_start nm-applet --indicator
maybe_start swaync
maybe_start ags
maybe_start blueman-applet
maybe_start waybar

# clipboard managers
if command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1; then
  (wl-paste --type text --watch cliphist store &)
  (wl-paste --type image --watch cliphist store &)
fi

# rainbow borders helper
USER_SCRIPTS="$HOME/.config/hypr/UserScripts"
if [[ -x "$USER_SCRIPTS/RainbowBorders.sh" ]]; then
  ("$USER_SCRIPTS/RainbowBorders.sh" &)
fi

# hypridle if available
maybe_start hypridle
