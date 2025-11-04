#!/usr/bin/env bash
# Link fastfetch image to current zsh theme picture
# Usage: run this once or from ~/.zshrc after changing theme

set -euo pipefail

FASTFETCH_DIR="$HOME/.config/fastfetch"
THEME_DIR="$FASTFETCH_DIR/theme-images"
TARGET_LINK="$FASTFETCH_DIR/current-theme.png"

# Try to get theme name from ~/.zshrc (oh-my-zsh)
ZSHRC="$HOME/.zshrc"
THEME_NAME=""
if [[ -f "$ZSHRC" ]]; then
  # Handle lines like: ZSH_THEME="agnoster" or ZSH_THEME='agnoster'
  THEME_NAME=$(grep -E "^\s*ZSH_THEME=\s*['\"]?[^'\"]+['\"]?" "$ZSHRC" | head -n1 | sed -E "s/.*ZSH_THEME=\s*['\"]?([^'\"]]+).*/\1/") || true
fi

pick_image() {
  local name="$1"
  if [[ -n "$name" ]]; then
    for ext in png jpg jpeg webp; do
      if [[ -f "$THEME_DIR/${name}.${ext}" ]]; then
        echo "$THEME_DIR/${name}.${ext}"
        return 0
      fi
    done
  fi
  # fallback to arch.png bundled image
  if [[ -f "$FASTFETCH_DIR/arch.png" ]]; then
    echo "$FASTFETCH_DIR/arch.png"
    return 0
  fi
  return 1
}

IMG_PATH=$(pick_image "$THEME_NAME") || {
  echo "No suitable image found. Put <theme>.png into $THEME_DIR or ensure $FASTFETCH_DIR/arch.png exists." >&2
  exit 1
}

mkdir -p "$FASTFETCH_DIR"
ln -sfn "$IMG_PATH" "$TARGET_LINK"

echo "Linked $TARGET_LINK -> $IMG_PATH"
