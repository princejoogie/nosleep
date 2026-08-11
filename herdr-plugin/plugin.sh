#!/usr/bin/env bash
set -euo pipefail

readonly PLUGIN_ID="nosleep.agent-awake"
readonly HERDR="${HERDR_BIN_PATH:-herdr}"
readonly STATE_DIR="${HERDR_PLUGIN_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/nosleep-herdr}"
readonly MONITOR_PIDFILE="$STATE_DIR/monitor.pid"
readonly CAFFEINATE_PIDFILE="$STATE_DIR/caffeinate.pid"
readonly LID_PIDFILE="$STATE_DIR/lid.pid"
readonly OWNED_FILE="$STATE_DIR/owns-disablesleep"
readonly ACTIVE_FILE="$STATE_DIR/active"
readonly DISPLAY_FILE="$STATE_DIR/display-id"
readonly BRIGHTNESS_FILE="$STATE_DIR/brightness"
readonly LOCK_DIR="$STATE_DIR/reconcile.lock"
readonly STOP_FILE="$STATE_DIR/stopped"
readonly REMOVING_FILE="$STATE_DIR/removing"
readonly POLL_INTERVAL=10

mkdir -p "$STATE_DIR"

brightness_bin() {
  if command -v nosleep-brightness >/dev/null 2>&1; then
    command -v nosleep-brightness
  elif [[ -x "$PWD/../nosleep-brightness" ]]; then
    printf '%s\n' "$PWD/../nosleep-brightness"
  else
    return 1
  fi
}

pid_matches() {
  local pid="$1" marker="$2"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ "$(ps -p "$pid" -o command= 2>/dev/null)" == *"$marker"* ]]
}

pmset_disabled() {
  [[ "$(pmset -g | awk 'tolower($0) ~ /sleepdisabled|disablesleep/ {print $2; exit}')" == "1" ]]
}

battery_is_low() {
  local output
  output="$(pmset -g batt 2>/dev/null)" || return 1
  [[ "$output" == *"'Battery Power'"* ]] || return 1
  [[ "$output" =~ ([0-9]+)% ]] || return 1
  [[ "${BASH_REMATCH[1]}" -le 20 ]]
}

has_working_agents() {
  local output socket found=1
  while IFS= read -r socket; do
    [[ -n "$socket" ]] || continue
    if output="$(HERDR_SOCKET_PATH="$socket" "$HERDR" agent list 2>/dev/null)" \
        && [[ "$output" =~ \"agent_status\"[[:space:]]*:[[:space:]]*\"working\" ]]; then
      found=0
      break
    fi
  done < <(session_sockets)
  return "$found"
}

session_sockets() {
  local output socket
  output="$("$HERDR" session list --json 2>/dev/null || true)"
  printf '%s\n' "$output" | grep -o '"socket_path":"[^"]*"' \
    | sed 's/^"socket_path":"//; s/"$//' || true
  socket="${HERDR_SOCKET_PATH:-}"
  [[ -z "$socket" || "$output" == *"\"socket_path\":\"$socket\""* ]] || printf '%s\n' "$socket"
}

restore_brightness() {
  local bin display saved
  bin="$(brightness_bin 2>/dev/null)" || return 0
  display="$(cat "$DISPLAY_FILE" 2>/dev/null || true)"
  saved="$(cat "$BRIGHTNESS_FILE" 2>/dev/null || true)"
  [[ -n "$saved" ]] || return 0
  if { [[ "$display" =~ ^[0-9]+$ ]] \
      && "$bin" --display "$display" set "$saved" >/dev/null 2>&1; } \
      || "$bin" set "$saved" >/dev/null 2>&1; then
    rm -f "$DISPLAY_FILE" "$BRIGHTNESS_FILE"
  fi
}

lid_monitor() {
  local bin state previous="" snapshot display="" saved="" self_pid current_pid
  self_pid="$(/bin/sh -c 'printf "%s\n" "$PPID"')"
  bin="$(brightness_bin 2>/dev/null)" || exit 0
  cleanup_lid() {
    restore_brightness
    current_pid="$(cat "$LID_PIDFILE" 2>/dev/null || true)"
    [[ "$current_pid" != "$self_pid" ]] || rm -f "$LID_PIDFILE"
  }
  trap 'exit 0' INT TERM HUP
  trap cleanup_lid EXIT

  while :; do
    state="$(ioreg -r -k AppleClamshellState -d 4 2>/dev/null \
      | awk '/"AppleClamshellState"/ {print ($NF == "Yes" ? "closed" : "open"); exit}')" \
      || state=""
    if [[ "$state" == "open" && "$previous" != "open" ]]; then
      restore_brightness
      if snapshot="$("$bin" snapshot 2>/dev/null)"; then
        display="${snapshot%% *}"
        saved="${snapshot#* }"
      fi
    elif [[ "$state" == "closed" && "$previous" != "closed" \
        && "$display" =~ ^[0-9]+$ && -n "$saved" ]]; then
      if [[ "$previous" == "open" ]]; then
        saved="$("$bin" --display "$display" get 2>/dev/null || printf '%s' "$saved")"
      fi
      printf '%s\n' "$display" > "$DISPLAY_FILE"
      printf '%s\n' "$saved" > "$BRIGHTNESS_FILE"
      "$bin" --display "$display" set 0 >/dev/null 2>&1 || true
    fi
    previous="$state"
    sleep 1
  done
}

activate() {
  local pid
  if ! pmset_disabled; then
    sudo -n /usr/bin/pmset -a disablesleep 1
    touch "$OWNED_FILE"
  fi

  pid="$(cat "$CAFFEINATE_PIDFILE" 2>/dev/null || true)"
  if ! pid_matches "$pid" "caffeinate"; then
    nohup caffeinate -dimsu >/dev/null 2>&1 </dev/null &
    echo $! > "$CAFFEINATE_PIDFILE"
  fi

  pid="$(cat "$LID_PIDFILE" 2>/dev/null || true)"
  if ! pid_matches "$pid" "_lid-monitor"; then
    nohup bash "$0" _lid-monitor >/dev/null 2>&1 </dev/null &
    echo $! > "$LID_PIDFILE"
  fi
  touch "$ACTIVE_FILE"
}

deactivate() {
  local pid lid_pid i
  lid_pid="$(cat "$LID_PIDFILE" 2>/dev/null || true)"
  if pid_matches "$lid_pid" "_lid-monitor"; then
    kill "$lid_pid" 2>/dev/null || true
    for ((i = 0; i < 20; i++)); do
      kill -0 "$lid_pid" 2>/dev/null || break
      sleep 0.1
    done
  fi
  pid="$(cat "$CAFFEINATE_PIDFILE" 2>/dev/null || true)"
  if pid_matches "$pid" "caffeinate"; then
    kill "$pid" 2>/dev/null || true
  fi
  restore_brightness
  pid_matches "$lid_pid" "_lid-monitor" || rm -f "$LID_PIDFILE"
  rm -f "$CAFFEINATE_PIDFILE" "$ACTIVE_FILE"

  if [[ -f "$OWNED_FILE" ]]; then
    if sudo -n /usr/bin/pmset -a disablesleep 0; then
      rm -f "$OWNED_FILE"
    else
      printf 'nosleep-herdr: unable to restore normal sleep; will retry.\n' >&2
    fi
  fi
}

reconcile() {
  (
    local owner
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      owner="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
      if [[ "$owner" =~ ^[0-9]+$ ]] && kill -0 "$owner" 2>/dev/null \
          && [[ "$(ps -p "$owner" -o command= 2>/dev/null)" == *"plugin.sh"* ]]; then
        exit 0
      fi
      rm -f "$LOCK_DIR/pid"
      rmdir "$LOCK_DIR" 2>/dev/null || exit 0
      mkdir "$LOCK_DIR" 2>/dev/null || exit 0
    fi
    # macOS ships Bash 3.2, where BASHPID is unavailable. A child's PPID is
    # this reconcile subshell's real process ID (unlike $$, which is inherited).
    /bin/sh -c 'printf "%s\n" "$PPID"' > "$LOCK_DIR/pid"
    trap 'rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
    if [[ ! -f "$STOP_FILE" ]] && has_working_agents && ! battery_is_low; then
      activate
    else
      deactivate
    fi
  )
}

plugin_state() {
  local output socket
  while IFS= read -r socket; do
    [[ -n "$socket" ]] || continue
    output="$(HERDR_SOCKET_PATH="$socket" "$HERDR" plugin list --plugin "$PLUGIN_ID" --json 2>/dev/null)" \
      || continue
    if [[ "$output" == *'"enabled":true'* ]]; then
      printf 'enabled\n'
      return
    elif [[ "$output" == *"\"plugin_id\":\"$PLUGIN_ID\""* ]]; then
      printf 'disabled\n'
      return
    fi
  done < <(session_sockets)
  printf 'missing\n'
}

monitor() {
  local state
  trap 'deactivate; rm -f "$MONITOR_PIDFILE"; exit 0' INT TERM HUP EXIT
  while :; do
    state="$(plugin_state)"
    case "$state" in
      enabled) reconcile ;;
      disabled) deactivate ;;
      missing) break ;;
    esac
    sleep "$POLL_INTERVAL"
  done
  deactivate
  trap - EXIT
  rm -f "$MONITOR_PIDFILE"
}

start() {
  local pid i force_restart=0
  [[ -n "${HERDR_PLUGIN_ACTION_ID:-}" ]] && force_restart=1
  if [[ -f "$STOP_FILE" ]]; then
    if [[ -n "${HERDR_PLUGIN_ACTION_ID:-}" ]]; then
      rm -f "$STOP_FILE" "$REMOVING_FILE"
    elif [[ ! -f "$REMOVING_FILE" ]] \
        && sudo -n /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1; then
      rm -f "$STOP_FILE" "$OWNED_FILE"
    else
      deactivate
      return
    fi
  fi
  pid="$(cat "$MONITOR_PIDFILE" 2>/dev/null || true)"
  if pid_matches "$pid" "_monitor"; then
    if [[ "$force_restart" == "0" ]]; then
      reconcile
      return
    fi
    kill "$pid" 2>/dev/null || true
    for ((i = 0; i < POLL_INTERVAL * 10 + 20; i++)); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    if pid_matches "$pid" "_monitor"; then
      printf 'nosleep-herdr: previous monitor did not stop.\n' >&2
      return 1
    fi
  fi
  nohup bash "$0" _monitor >/dev/null 2>&1 </dev/null &
  echo $! > "$MONITOR_PIDFILE"
  reconcile
}

status() {
  local pid
  pid="$(cat "$MONITOR_PIDFILE" 2>/dev/null || true)"
  if pid_matches "$pid" "_monitor"; then
    printf 'monitor: running\n'
  else
    printf 'monitor: stopped\n'
  fi
  if [[ -f "$ACTIVE_FILE" ]]; then
    printf 'nosleep: active\n'
  else
    printf 'nosleep: inactive\n'
  fi
}

remove_helper() {
  local uid pid i
  touch "$STOP_FILE" "$REMOVING_FILE"
  pid="$(cat "$MONITOR_PIDFILE" 2>/dev/null || true)"
  if pid_matches "$pid" "_monitor"; then
    kill "$pid" 2>/dev/null || true
    for ((i = 0; i < POLL_INTERVAL * 10 + 20; i++)); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
  fi
  deactivate
  if [[ -f "$OWNED_FILE" ]]; then
    printf 'nosleep-herdr: normal sleep could not be restored; permission was not removed.\n' >&2
    printf 'Press Enter to close.\n'
    read -r _
    return 1
  fi
  uid="$(id -u)"
  if ! sudo /bin/rm -f "/etc/sudoers.d/nosleep-herdr-$uid"; then
    rm -f "$REMOVING_FILE"
    printf 'nosleep-herdr: system permission was not removed.\n' >&2
    printf 'Press Enter to close.\n'
    read -r _
    return 1
  fi
  rm -f "$REMOVING_FILE"
  printf 'nosleep-herdr: system permission removed.\n'
  printf 'Press Enter to close.\n'
  read -r _
}

case "${1:-}" in
  start)        start ;;
  reconcile)    reconcile ;;
  status)       status ;;
  remove-helper) remove_helper ;;
  _monitor)     monitor ;;
  _lid-monitor) lid_monitor ;;
  *) printf 'usage: plugin.sh <start|reconcile|status|remove-helper>\n' >&2; exit 1 ;;
esac
