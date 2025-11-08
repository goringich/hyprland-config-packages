#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_CONFIG="$REPO_ROOT/.config"
DEST_CONFIG="$HOME/.config"
PKG_NATIVE="$REPO_ROOT/pkglist.txt"
PKG_AUR="$REPO_ROOT/aur-pkglist.txt"

# 0) Pre-flight
if ! command -v rsync >/dev/null; then
  echo "rsync is required. Installing (sudo)..."
  sudo pacman -Syu --needed rsync
fi

# 1) Backup existing configs
BK="$HOME/config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
if [[ -d "$DEST_CONFIG" ]]; then
  rsync -a "$DEST_CONFIG/" "$BK/"
  echo "Backup saved to: $BK"
fi

# 2) Copy configs from repo
if [[ -d "$SRC_CONFIG" ]]; then
  rsync -a --delete "$SRC_CONFIG/" "$DEST_CONFIG/"
  echo "Configs synced to $DEST_CONFIG"
else
  echo "No .config directory found in repo at $SRC_CONFIG" >&2
fi

# 3) Install native packages
if [[ -f "$PKG_NATIVE" ]]; then
  echo "Installing native packages from pkglist.txt (sudo pacman)..."
  sudo pacman -Syu --needed - < "$PKG_NATIVE"
fi

# 4) Install AUR packages (optional)
if [[ -f "$PKG_AUR" ]]; then
  if command -v yay >/dev/null; then
    echo "Installing AUR packages from aur-pkglist.txt (yay)..."
    yay -S --needed - < "$PKG_AUR"
  else
    echo "aur-pkglist.txt found but no AUR helper (yay) installed. Skip."
  fi
fi

# 5) Hyprland session notice
if command -v hyprctl >/dev/null; then
  echo "You can reload Hyprland configs with: hyprctl reload"
  echo "Or restart session: hyprctl dispatch exit 0"
fi
