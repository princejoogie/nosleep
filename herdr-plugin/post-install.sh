#!/usr/bin/env bash
set -euo pipefail

readonly PLUGIN_ID="nosleep.agent-awake"
readonly HERDR="${HERDR_BIN_PATH:-herdr}"
readonly READY_FILE="${1:-}"

[[ -z "$READY_FILE" ]] || touch "$READY_FILE"

for ((i = 0; i < 30; i++)); do
  sessions="$("$HERDR" session list --json 2>/dev/null || true)"
  while IFS= read -r socket; do
    [[ -n "$socket" ]] || continue
    output="$(HERDR_SOCKET_PATH="$socket" "$HERDR" plugin list --plugin "$PLUGIN_ID" --json 2>/dev/null || true)"
    if [[ "$output" == *'"enabled":true'* ]]; then
      if HERDR_SOCKET_PATH="$socket" "$HERDR" plugin action invoke start --plugin "$PLUGIN_ID" >/dev/null 2>&1; then
        exit 0
      fi
    fi
  done < <(printf '%s\n' "$sessions" | grep -o '"socket_path":"[^"]*"' \
    | sed 's/^"socket_path":"//; s/"$//' || true)
  sleep 1
done

exit 1
