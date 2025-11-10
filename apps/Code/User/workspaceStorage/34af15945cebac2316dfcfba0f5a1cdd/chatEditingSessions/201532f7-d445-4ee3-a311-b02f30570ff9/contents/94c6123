#!/usr/bin/env bash
set -euo pipefail

label="Linux"
if [ -r /etc/os-release ]; then
  . /etc/os-release || true
  label="${NAME:-${ID:-Linux}}"
  combined="${NAME:-} ${ID:-}"
  if printf '%s' "$combined" | grep -qi 'cachy'; then
    echo " CachyOS"
    exit 0
  fi
  if printf '%s' "$combined" | grep -qi 'arch'; then
    echo " Arch"
    exit 0
  fi
fi
printf ' %s
' "$label"
