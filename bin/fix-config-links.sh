#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/.config"

cats=(wm terminal apps visuals core)

STATEFUL_FILE="$HOME/.config/stateful-dirs.txt"
STATEFUL_TEMPLATE_ROOT="$HOME/.config/stateful-templates"

if [[ -f "$STATEFUL_FILE" ]]; then
  mapfile -t STATEFUL_DIRS < <(grep -Ev '^\s*#|^\s*$' "$STATEFUL_FILE")
else
  mapfile -t STATEFUL_DIRS < <(cat <<'EOF'
Code
Code - OSS
google-chrome

for name in "${STATEFUL_DIRS[@]}"; do
  seed_stateful_from_template "$name"
done
google-chrome-for-testing
Electron
obsidian
EOF
)
fi

is_stateful() {
  local candidate="$1"
  for dir in "${STATEFUL_DIRS[@]}"; do
    if [[ "$dir" == "$candidate" ]]; then
      return 0
    fi
  done
  return 1
}

detach_symlink_dir() {
  local path="$1"
  if [[ -L "$path" ]]; then
    local tmp
    tmp="$(mktemp -d)"
    cp -a "${path}/." "$tmp/"
    rm "$path"
    mkdir -p "$path"
    cp -a "${tmp}/." "$path/"
    rm -rf "$tmp"
    echo "stateful: converted symlink at ${path#$HOME/} into a real directory"
  fi
}

seed_stateful_from_template() {
  local name="$1"
  local target="$HOME/.config/$name"
  local template_dir="$STATEFUL_TEMPLATE_ROOT/$name"

  detach_symlink_dir "$target"

  if [[ ! -d "$target" ]]; then
    mkdir -p "$target"
    echo "stateful: initialized $name"
  fi

  if [[ -d "$template_dir" ]]; then
    cp -an "${template_dir}/." "$target/" || true
  fi

  if [[ "$name" == "Code" ]]; then
    local user_dir="$target/User"
    local template_settings="$template_dir/User/settings.json"
    if [[ -f "$template_settings" ]]; then
      mkdir -p "$user_dir"
      local target_settings="$user_dir/settings.json"
      if [[ -L "$target_settings" ]]; then
        local resolved
        resolved="$(readlink -f "$target_settings" 2>/dev/null || true)"
        if [[ "$resolved" != "$template_settings" ]]; then
          rm "$target_settings"
        fi
      elif [[ -e "$target_settings" ]]; then
        local backup="$target_settings.bak.$(date +%s)"
        mv "$target_settings" "$backup"
        echo "stateful: backed up existing ${target_settings#$HOME/} -> ${backup#$HOME/}"
      fi
      ln -sf "$template_settings" "$target_settings"
      echo "stateful: linked Code/User/settings.json to template"
    fi
  fi
}
for cat in "${cats[@]}"; do
  [ -d "$cat" ] || continue
  while IFS= read -r -d '' entry; do
    name="$(basename "$entry")"
    target="$HOME/.config/$name"
    src="$HOME/.config/$cat/$name"
    if is_stateful "$name"; then
      continue
    fi

    if [ -L "$target" ]; then
      continue
    fi
    if [ -e "$target" ]; then
      echo "skip: $name exists"
      continue
    fi
    ln -s "$src" "$target"
    echo "link: $name -> $cat/$name"
  done < <(find "$cat" -mindepth 1 -maxdepth 1 -print0)
done

if [ -d core/environment.d ] && [ ! -e environment.d ]; then
  ln -s core/environment.d environment.d
  echo "link: environment.d -> core/environment.d"
fi
