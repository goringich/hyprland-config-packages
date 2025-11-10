#!/usr/bin/env bash
# Simple CachyOS / Arch style ASCII banner with system info
set -euo pipefail

# Detect CachyOS or Arch
OS_NAME="Arch"
if [ -r /etc/os-release ]; then
  . /etc/os-release || true
  if printf '%s %s' "$NAME" "$ID" | grep -qi cachy; then
    OS_NAME="CachyOS"
  elif printf '%s %s' "$NAME" "$ID" | grep -qi arch; then
    OS_NAME="Arch"
  fi
fi

# Colors
c_rst="\033[0m"
c_b="\033[1m"
c_blue="\033[34m"
c_cyan="\033[36m"
c_mag="\033[35m"
c_dim="\033[2m"

KERNEL=$(uname -r)
HOST=$(uname -n)
UPTIME=$(uptime -p | sed 's/^up //')
if read -r la rest < /proc/loadavg; then
  LOAD="$la"
else
  LOAD="n/a"
fi
MEM=$(free -m | awk '/Mem:/ {printf "%d/%dMB", $3, $2}')
CPU=$(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')
CPU_SHORT=$(printf '%s\n' "$CPU" | sed 's/@.*//; s/[[:space:]]*$//')

printf '%b\n' "${c_mag}${c_b}      ___           _           ${c_blue}${OS_NAME}${c_rst}"
printf '%b\n' "${c_mag}${c_b}     / __\\__ _  ___| |__   ___  ${c_cyan}Host${c_rst}: ${HOST}"
printf '%b\n' "${c_mag}${c_b}    / /  / _\` |/ __| '_ \\ / _ \\ ${c_cyan}Kernel${c_rst}: ${KERNEL}"
printf '%b\n' "${c_mag}${c_b}   / /__| (_| | (__| | | |  __/ ${c_cyan}Uptime${c_rst}: ${UPTIME}"
printf '%b\n' "${c_mag}${c_b}   \\____/\\__,_|\\___|_| |_|\\___| ${c_cyan}Load${c_rst}: ${LOAD}"
printf '%b\n' "${c_mag}${c_b}                       ${c_cyan}Mem${c_rst}: ${MEM}"
printf '%b\n' "${c_mag}${c_b}                       ${c_cyan}CPU${c_rst}: ${CPU_SHORT}"
printf '%b\n' "${c_dim}Tip: disable banner: comment show-cachyos-banner.sh in fish config${c_rst}"
