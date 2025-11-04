#!/usr/bin/env bash
set -euo pipefail

CONFIG_ROOT="$HOME/.config"
TARGET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTCONFIG="$TARGET_ROOT/.config"

mkdir -p "$DOTCONFIG"

mapfile -t CONFIG_DIRS < <(cat <<'EOF'
ags
hypr
waybar
waybar.backup
rofi
kitty
qt5ct
qt6ct
Kvantum
gtk-3.0
gtk-4.0
fastfetch
swaync
swappy
wallust
wlogout
btop
bpytop
cava
mpv
pipewire
EOF
)

sync_dir() {
  local dir="$1"
  local source_path="$CONFIG_ROOT/$dir"
  local target_path="$DOTCONFIG/$dir"

  if [[ -d "$source_path" ]]; then
    mkdir -p "$target_path"
    rsync -a --delete "$source_path/" "$target_path/"
    echo "synced directory $dir"
  else
    echo "skipped missing directory $dir" >&2
  fi
}

for dir in "${CONFIG_DIRS[@]}"; do
  sync_dir "$dir"
done

STARSHIP_FILE="starship.toml"
if [[ -f "$CONFIG_ROOT/$STARSHIP_FILE" ]]; then
  install -D "$CONFIG_ROOT/$STARSHIP_FILE" "$DOTCONFIG/$STARSHIP_FILE"
  echo "synced file $STARSHIP_FILE"
else
  echo "skipped missing file $STARSHIP_FILE" >&2
fi

pacman -Qqe > "$TARGET_ROOT/pkglist.txt"
echo "refreshed pkglist.txt"
