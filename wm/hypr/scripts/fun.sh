#!/usr/bin/env bash
# ~/.config/hypr/scripts/fun.sh
set -euo pipefail

TERMINAL="${TERMINAL:-kitty}"
LOGDIR="${HOME}/logs/fun-$(date +%F)"
DEBUG="${DEBUG:-0}"

TELNET_HOST="telehack.com"
TELNET_PORT=23
TOWEL_HOST="towel.blinkenlights.nl"
TOWEL_PORT=23
EXPECT_TIMEOUT=60

mkdir -p "$LOGDIR"

echod() { [ "$DEBUG" = "1" ] && printf '%s\n' "$*" >&2 || true; }

which_or_err() { command -v "$1" >/dev/null 2>&1; }

detect_terminal_supports_kitty_remote() {
  if which_or_err kitty && kitty --version >/dev/null 2>&1 && kitty @ ls >/dev/null 2>&1; then
    echo "kitty"
    return 0
  fi
  echo ""
}

check_and_report() {
  local miss=()
  for cmd in bash date mktemp sed awk mkdir; do
    which_or_err "$cmd" || miss+=("$cmd")
  done
  if [ "${#miss[@]}" -ne 0 ]; then
    echo "missing required commands: ${miss[*]}" >&2
    exit 2
  fi
  for cmd in expect telnet nc bpytop btop cmatrix pipes.sh notify-send tmux fzf kitty alacritty cbonsai cava; do
    which_or_err "$cmd" || echod "optional not found: $cmd"
  done
}

notify() {
  which_or_err notify-send && notify-send --hint=int:transient:1 "$1" "$2" || true
}

launch_in_kitty_remote() {
  local title="$1"; local cmd="$2"
  kitty @ new-window --title "$title" bash -lc "$cmd" >/dev/null 2>&1 || return 1
}

launch_terminal_fallback() {
  local cmd="$1"
  if which_or_err "$TERMINAL"; then
    "$TERMINAL" -e bash -ic "$cmd" >/dev/null 2>&1 &
  else
    xterm -e bash -ic "$cmd" >/dev/null 2>&1 &
  fi
}

run_in_tab() {
  local title="$1"; local cmd="$2"
  if [ "$KITTY_REMOTE" = "kitty" ]; then
    launch_in_kitty_remote "$title" "$cmd; exit" || launch_terminal_fallback "$cmd"
  else
    launch_terminal_fallback "$cmd"
  fi
}

launch_cmatrix() {
  local logfile="$LOGDIR/cmatrix-$(date +%s).log"
  local cmd='cmatrix; echo; echo "cmatrix exited - press ENTER to close"; read -r'
  run_in_tab "cmatrix" "$cmd >\"$logfile\" 2>&1"
  echod "cmatrix -> $logfile"
}

launch_bpytop() {
  local whichbp="btop"
  which_or_err bpytop && whichbp="bpytop"
  local logfile="$LOGDIR/$whichbp-$(date +%s).log"
  local cmd="$whichbp; echo; echo '$whichbp exited - press ENTER to close'; read -r"
  run_in_tab "$whichbp" "$cmd >\"$logfile\" 2>&1"
  echod "$whichbp -> $logfile"
}

launch_pipes() {
  local logfile="$LOGDIR/pipes-$(date +%s).log"
  local cmd='pipes.sh -p 8 -r -B; echo; echo "pipes.sh ended - press ENTER to close"; read -r'
  run_in_tab "pipes" "$cmd >\"$logfile\" 2>&1"
  echod "pipes.sh -> $logfile"
}

launch_cbonsai() {
  local logfile="$LOGDIR/cbonsai-$(date +%s).log"
  local cmd='(cbonsai -l -t 35 -S 5 || cbonsai -l -t 0.035 -S 5 || cbonsai -l -S 5); echo; echo "cbonsai ended - press ENTER to close"; read -r'
  run_in_tab "cbonsai" "$cmd >\"$logfile\" 2>&1"
  echod "cbonsai -> $logfile"
}

launch_cava() {
  local logfile="$LOGDIR/cava-$(date +%s).log"
  local cmd='cava; echo; echo "cava ended - press ENTER to close"; read -r'
  run_in_tab "cava" "$cmd >\"$logfile\" 2>&1"
  echod "cava -> $logfile"
}

launch_starwars_expect() {
  local logfile="$LOGDIR/starwars-$(date +%s).log"
  local host="towel.blinkenlights.nl"
  local port=23

  # diagnostics: сначала проверяем, можно ли установить TCP-соединение
  if command -v nc >/dev/null 2>&1; then
    echo "[$(date +%T)] checking nc reachability to $host:$port" >>"$logfile"
    if nc -zv "$host" "$port" 2>>"$logfile" >/dev/null; then
      echo "[$(date +%T)] nc connect test: ok" >>"$logfile"
      run_in_tab "starwars" "echo '[connecting via nc]' | tee -a '$logfile'; timeout 300 bash -c 'nc -w 5 $host $port | tee -a \"$logfile\"' || true"
      echod "starwars -> $logfile (used nc)"
      return 0
    else
      echo "[$(date +%T)] nc connect test: failed" >>"$logfile"
      echod "nc connect failed, trying telnet"
    fi
  else
    echod "nc not installed"
    echo "[$(date +%T)] nc not installed" >>"$logfile"
  fi

  # если nc не сработал — пробуем telnet (inetutils)
  if command -v telnet >/dev/null 2>&1; then
    echo "[$(date +%T)] trying telnet to $host:$port" >>"$logfile"
    run_in_tab "starwars" "echo '[connecting via telnet]' | tee -a '$logfile'; timeout 300 bash -c 'telnet $host $port 2>&1 | tee -a \"$logfile\"' || true"
    echod "starwars -> $logfile (used telnet)"
    return 0
  else
    echod "telnet not installed"
    echo "[$(date +%T)] telnet not installed" >>"$logfile"
  fi

  # если ни nc, ни telnet не помогли — фолбэк: hollywood (красивый терминал-спектакль)
  echo "[$(date +%T)] falling back to hollywood (telnet blocked or no tool available)" >>"$logfile"
  if command -v hollywood >/dev/null 2>&1; then
    run_in_tab "hollywood" "hollywood 2>&1 | tee -a '$logfile'"
    echod "hollywood fallback -> $logfile"
  else
    echo "[$(date +%T)] hollywood not installed; nothing to run" >>"$logfile"
    echod "no suitable tool found: install openbsd-netcat (nc) or telnet or hollywood"
  fi
}




launch_starwars_towel_fallback() {
  local logfile="$LOGDIR/starwars-towel-$(date +%s).log"
  local cmd="telnet $TOWEL_HOST $TOWEL_PORT || nc -v $TOWEL_HOST $TOWEL_PORT"
  local wrap="$cmd | tee '$logfile'; echo; echo 'towel ended - press ENTER to close'; read -r"
  run_in_tab "starwars-towel" "$wrap"
  echod "towel -> $logfile"
}

launch_starwars_nc_fallback() {
  local host="$1"; local port="$2"; local prefix="${3:-true}"
  which_or_err nc || { echod "nc not found"; return 1; }
  local logfile="$LOGDIR/starwars-nc-$(date +%s).log"
  local cmd="$prefix | nc -v $host $port"
  local wrap="$cmd | tee '$logfile'; echo; echo 'nc session ended - press ENTER to close'; read -r"
  run_in_tab "starwars-nc" "$wrap"
  echod "nc fallback -> $logfile"
}

cleanup() {
  jobs -p | xargs -r kill 2>/dev/null || true
  rm -f /tmp/fun_expect.* 2>/dev/null || true
}

wait_for_children() {
  while true; do
    sleep 1
    jobs -p >/dev/null 2>&1 || break
  done
}

main() {
  check_and_report
  KITTY_REMOTE="$(detect_terminal_supports_kitty_remote)"
  echod "KITTY_REMOTE=$KITTY_REMOTE"
  notify "fun.sh" "starting"

  local choice="all"
  if which_or_err fzf && [ -t 1 ]; then
    choice=$(printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "all" "cmatrix" "bpytop" "starwars" "pipes" "cbonsai" "cava" | fzf --height=10 --prompt="select: ")
    choice=${choice:-all}
  fi

  trap cleanup SIGINT SIGTERM EXIT

  case "$choice" in
    all)
      launch_cmatrix &
      sleep 0.25
      launch_bpytop &
      sleep 0.25
      launch_starwars_expect &
      sleep 0.10
      launch_pipes &
      sleep 0.10
      launch_cbonsai &
      sleep 0.10
      launch_cava &
      ;;
    cmatrix) launch_cmatrix ;;
    bpytop) launch_bpytop ;;
    starwars) launch_starwars_expect ;;
    pipes) launch_pipes ;;
    cbonsai) launch_cbonsai ;;
    cava) launch_cava ;;
    *) echo "unknown: $choice" >&2; exit 1 ;;
  esac

  wait_for_children
  notify "fun.sh" "finished"
}

main "$@"
