#!/usr/bin/env bash
set -euo pipefail

CONFIG_ROOT="$HOME/.config"
TARGET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTCONFIG="$TARGET_ROOT/.config"
EXCLUDES_FILE="$TARGET_ROOT/rsync-excludes.txt"

mkdir -p "$DOTCONFIG"

ALLOWLIST_FILE="$TARGET_ROOT/config-allowlist.txt"

if [[ -f "$ALLOWLIST_FILE" ]]; then
  # read non-comment, non-empty lines
  mapfile -t CONFIG_DIRS < <(grep -Ev '^\s*#|^\s*$' "$ALLOWLIST_FILE")
else
  echo "[warn] allowlist file not found, falling back to embedded list" >&2
  mapfile -t CONFIG_DIRS < <(cat <<'EOF'
ags
hypr
waybar
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
wofi
EOF
)
fi

sync_dir() {
  local dir="$1"
  local source_path="$CONFIG_ROOT/$dir"
  local target_path="$DOTCONFIG/$dir"

  if [[ -d "$source_path" ]]; then
    mkdir -p "$target_path"
    if [[ -f "$EXCLUDES_FILE" ]]; then
      rsync -a --delete --exclude-from="$EXCLUDES_FILE" "$source_path/" "$target_path/"
    else
      rsync -a --delete "$source_path/" "$target_path/"
    fi
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
echo "refreshed pkglist.txt (explicit pacman packages)"

# Optional: detect AUR helper and generate aur-pkglist.txt (packages not in repo db)
if command -v yay &>/dev/null; then
  # List all explicitly installed packages; filter those whose source is AUR via yay -Qi | grep -F 'AUR'
  mapfile -t AUR_PKGS < <(yay -Qm | awk '{print $1}')
  if ((${#AUR_PKGS[@]})); then
    printf '%s
' "${AUR_PKGS[@]}" > "$TARGET_ROOT/aur-pkglist.txt"
    echo "refreshed aur-pkglist.txt (${#AUR_PKGS[@]} AUR packages)"
  fi
fi
