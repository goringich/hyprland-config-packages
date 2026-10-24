#!/usr/bin/env bash
set -euo pipefail

# Wait for the existing local Hiddify proxy before restoring Chrome.
# Use the canonical hidi facade to request the last selected Hiddify profile.
# Never save subscription URLs, profiles, or proxy credentials here.

readonly log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
readonly log_file="$log_dir/vpn-first-startup.log"
readonly proxy_host="${HIDDIFY_PROXY_HOST:-127.0.0.1}"
readonly proxy_port="${HIDDIFY_PROXY_PORT:-12334}"
readonly check_url="${HIDDIFY_CHECK_URL:-https://www.cloudflare.com/cdn-cgi/trace}"
readonly wait_seconds="${HIDDIFY_WAIT_SECONDS:-300}"
readonly hidi_timeout="${HIDDIFY_ACTIVATION_TIMEOUT:-90}"

mkdir -p "$log_dir"
log() {
  printf '%s %s\n' "$(date -Is)" "$*" >> "$log_file"
}

log "VPN-first startup begin"

if [[ ! "$proxy_port" =~ ^[0-9]+$ ]] || (( proxy_port < 1 || proxy_port > 65535 )); then
  log "Invalid HIDDIFY_PROXY_PORT"
  exit 1
fi
if [[ ! "$wait_seconds" =~ ^[0-9]+$ ]] || [[ ! "$hidi_timeout" =~ ^[0-9]+$ ]]; then
  log "Invalid startup timeout"
  exit 1
fi
if ! command -v hyprctl >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  log "Missing hyprctl or curl; refusing to start Chrome"
  exit 1
fi

window_exists() {
  local pattern="$1"
  command -v jq >/dev/null 2>&1 || return 1
  hyprctl clients -j 2>/dev/null |
    jq -e --arg regex "$pattern" '
      any(.[]; ((.class // "") | test($regex; "i")))
    ' >/dev/null 2>&1
}

launch_hiddify_if_missing() {
  local binary=""
  local candidate=""

  if window_exists 'hiddify'; then
    log "Hiddify UI already running; skipping duplicate launch"
    return 0
  fi

  for candidate in hiddify Hiddify hiddify-next; do
    if command -v "$candidate" >/dev/null 2>&1; then
      binary="$(command -v "$candidate")"
      break
    fi
  done

  if [[ -n "$binary" ]]; then
    hyprctl dispatch exec "[workspace 5 silent] $binary" >/dev/null
    log "Requested Hiddify UI on workspace 5"
    return 0
  fi

  if command -v gtk-launch >/dev/null 2>&1; then
    hyprctl dispatch exec '[workspace 5 silent] gtk-launch app.hiddify.com' >/dev/null
    log "Requested Hiddify desktop entry on workspace 5"
    return 0
  fi

  log "No Hiddify desktop launcher; hidi may still provide headless VPN"
  return 1
}

proxy_ready() {
  curl --silent --show-error --fail --output /dev/null \
    --connect-timeout 3 --max-time 5 \
    --noproxy '' --proxy "socks5h://$proxy_host:$proxy_port" \
    "$check_url" >/dev/null 2>&1
}

request_last_profile() {
  if ! command -v hidi >/dev/null 2>&1; then
    log "hidi unavailable; start Hiddify GUI but cannot auto-connect last profile"
    launch_hiddify_if_missing || true
    return 0
  fi

  # provider-on restores the last profile without privileged Codex egress
  # convergence. A graphical startup must never run the sudo-dependent 'hidi on'.
  (
    local rc=0
    timeout --signal=TERM --kill-after=5s "${hidi_timeout}s" \
      hidi provider-on </dev/null >/dev/null 2>&1 || rc=$?
    log "hidi provider-only activation finished rc=$rc"
  ) &
  log "Requested last Hiddify profile via hidi provider-on"
}

launch_chrome() {
  local command_file="$HOME/.config/hypr/UserConfigs/VpnFirstBrowserCommand"
  local browser_command=""
  local var_ref='$scriptsDir'
  local resolved_scripts="$HOME/.config/hypr/scripts"

  if window_exists 'google-chrome|chromium|brave-browser'; then
    log "Browser already open; skipping duplicate startup"
    return 0
  fi

  if [[ -f "$command_file" ]]; then
    IFS= read -r browser_command < "$command_file" || true
    if [[ -z "$browser_command" ]]; then
      log "Saved browser command empty; refusing startup"
      return 1
    fi

    # Hyprland expands $scriptsDir in exec-once but not inside a command
    # loaded from an ordinary text file and passed to hyprctl dispatch exec.
    browser_command="${browser_command//"$var_ref"/"$resolved_scripts"}"
  else
    local chrome="$HOME/.local/bin/google-chrome-stable"
    if [[ ! -x "$chrome" ]]; then
      chrome="$(command -v google-chrome-stable || true)"
    fi
    if [[ -z "$chrome" ]]; then
      log "Chrome wrapper missing"
      return 1
    fi
    browser_command="$chrome --restore-last-session"
  fi

  if [[ "$browser_command" == *'SessionStartupGuard.sh'* ]] &&
    [[ ! -f "$resolved_scripts/SessionStartupGuard.sh" ]]; then
    log "SessionStartupGuard missing; refusing to bypass normal/safe-mode guard"
    return 1
  fi

  # Hyprland dispatch queues the original guarded command; safe mode may
  # intentionally skip launching Chrome and other restored applications.
  local state="$HOME/.local/state/session-startup-guard/state.env"
  if [[ "$browser_command" == *'SessionStartupGuard.sh'* ]] &&
    [[ -f "$state" ]] &&
    grep -Eq "^SAFE_MODE='?1'?$" "$state"; then
    log "Session safe mode active; original Chrome guard may skip launch"
  fi

  hyprctl dispatch exec "[workspace 1 silent] $browser_command" >/dev/null
  log "Dispatched original guarded Chrome command after proxy check; window creation not confirmed"
}

# The already-connected case does not reconfigure a healthy provider.
if proxy_ready; then
  log "Existing Hiddify proxy ready"
  launch_hiddify_if_missing || true
else
  # This is the only path that actively attempts last-profile restoration.
  # Window placement for Hiddify's systemd-run launcher is handled by rules.
  request_last_profile
fi

for (( second = 0; second <= wait_seconds; second += 3 )); do
  if proxy_ready; then
    launch_chrome
    exit $?
  fi
  if (( second < wait_seconds )); then
    sleep 3
  fi
done

log "No verified Hiddify proxy after ${wait_seconds}s; Chrome remains closed"
exit 1
