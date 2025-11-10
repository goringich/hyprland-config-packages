#!/usr/bin/env bash
set -euo pipefail

if read -r la _rest < /proc/loadavg 2>/dev/null; then
  printf 'LA %s
' "$la"
fi
