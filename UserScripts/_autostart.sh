#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/.config/UserScripts/autostart.d"
[ -d "$DIR" ] || exit 0

for f in "$DIR"/*; do
  [ -f "$f" ] || continue
  # если есть shebang — запустим как есть; иначе подберём интерпретатор по расширению
  if head -n1 "$f" | grep -q '^#!'; then
    # не дублируем процессы
    pgrep -f -- "$f" >/dev/null 2>&1 || "$f" &
  else
    case "$f" in
      *.sh) pgrep -f -- "$f" >/dev/null 2>&1 || bash "$f" & ;;
      *.py) pgrep -f -- "$f" >/dev/null 2>&1 || python "$f" & ;;
      *)    pgrep -f -- "$f" >/dev/null 2>&1 || bash "$f" & ;;
    esac
  fi
done
