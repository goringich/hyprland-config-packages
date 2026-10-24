#!/usr/bin/env bash
set -euo pipefail

# Keep Chrome closed until Hiddify's local proxy can reach a remote endpoint.
# Hiddify 4.1.1 does not automatically connect the last profile on desktop.
# This script does not claim to establish the VPN connection itself.

readonly log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
readonly log_file="$log_dir/vpn-first-startup.log"
readonly proxy_host="${HIDDIFY_PROXY_HOST:-127.0.0.1}"
readonly proxy_port="${HIDDIFY_PROXY_PORT:-12334}"
readonly check_url="${HIDDIFY_CHECK_URL:-https://www.cloudflare.com/cdn-cgi/trace}"
readonly wait_seconds="${HIDDIFY_WAIT_SECONDS:-300}"

mkdir -p "$log_dir"
log() {
  printf '%s %s\n' "$(date -Is)" "$*" >> "$log_file"
}

if [[ ! "$proxy_port" =~ ^[0-9]+$ ]] || (( proxy_port < 1 || proxy_port > 65535 )); then
  log "Invalid HIDDIFY_PROXY_PORT"
  exit 1
fi
if [[ ! "$wait_seconds" =~ ^[0-9]+$ ]]; then
  log "Invalid HIDDIFY_WAIT_SECONDS"
  exit 1
fi
if ! command -v hyprctl >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  log "Missing hyprctl or curl; refusing to launch Chrome without VPN verification"
  exit 1
fi

launch_hiddify() {
  local binary=""
  local candidate=""
  for candidate in hiddify Hiddify hiddify-next; do
    if command -v "$candidate" >/dev/null 2>&1; then
      binary="$(command -v "$candidate")"
      break
    fi
  done

  if [[ -n "$binary" ]]; then
    hyprctl dispatch exec "[workspace 5 silent] $binary" >/dev/null
    log "Requested Hiddify on workspace 5"
    return 0
  fi

  if command -v gtk-launch >/dev/null 2>&1; then
    hyprctl dispatch exec '[workspace 5 silent] gtk-launch app.hiddify.com' >/dev/null
    log "Requested Hiddify desktop entry on workspace 5"
    return 0
  fi

  log "Hiddify executable or desktop launcher unavailable"
  return 1
}

proxy_ready() {
  curl --silent --show-error --fail --output /dev/null \
    --connect-timeout 3 --max-time 5 \
    --noproxy '' --proxy "socks5h://$proxy_host:$proxy_port" \
    "$check_url" >/dev/null 2>&1
}

launch_chrome() {
  local chrome="$HOME/.local/bin/google-chrome-stable"
  if [[ ! -x "$chrome" ]]; then
    chrome="$(command -v google-chrome-stable || true)"
  fi
  if [[ -z "$chrome" ]]; then
    log "Chrome wrapper and google-chrome-stable are missing"
    return 1
  fi

  hyprctl dispatch exec "[workspace 1 silent] $chrome --restore-last-session" >/dev/null
  log "Requested Chrome on workspace 1 after proxy check"
}

launch_hiddify || exit 1

for (( second = 0; second <= wait_seconds; second += 3 )); do
  if proxy_ready; then
    launch_chrome
    exit $?
  fi
  if (( second < wait_seconds )); then
    sleep 3
  fi
done

log "Hiddify proxy did not become ready within ${wait_seconds}s; Chrome remains closed"
exit 1
