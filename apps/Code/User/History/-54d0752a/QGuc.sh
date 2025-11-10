#!/usr/bin/env bash
set -euo pipefail

if ! command -v uptime >/dev/null 2>&1; then
  exit 0
fi

out=$(uptime -p 2>/dev/null | sed \
  -e 's/^up //' \
  -e 's/ days\?/d/' \
  -e 's/ day/d/' \
  -e 's/ hours\?/h/' \
  -e 's/ hour/h/' \
  -e 's/ minutes\?/m/' \
  -e 's/ minute/m/')

printf '%s
' "$out"
