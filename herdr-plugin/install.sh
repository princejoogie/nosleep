#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

[[ "$(uname -s)" == "Darwin" ]] || {
  printf 'nosleep-herdr: macOS is required.\n' >&2
  exit 1
}

user="$(id -un)"
uid="$(id -u)"
herdr_bin="$(command -v herdr)"
[[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] || {
  printf 'nosleep-herdr: unsupported username: %s\n' "$user" >&2
  exit 1
}

printf 'nosleep-herdr needs one-time permission to toggle the macOS sleep switch.\n'
sudo /bin/bash -s -- "$user" "/etc/sudoers.d/nosleep-herdr-$uid" "$HOME" "$herdr_bin" <<'ROOT'
set -euo pipefail
user="$1"
target="$2"
tmp="$(mktemp /etc/sudoers.d/.nosleep-herdr.XXXXXX)"
trap 'rm -f "$tmp"' EXIT
printf '%s ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0\n' "$user" > "$tmp"
chown root:wheel "$tmp"
chmod 0440 "$tmp"
/usr/sbin/visudo -cf "$tmp" >/dev/null
mv -f "$tmp" "$target"
trap - EXIT

# Registration happens after this build command returns. A detached root
# watchdog removes the grant if Herdr never exposes the enabled plugin.
nohup /bin/bash -s -- "$user" "$3" "$4" "$target" >/dev/null 2>&1 <<'WATCHDOG' &
set -u
user="$1"; home="$2"; herdr="$3"; target="$4"
for ((i = 0; i < 60; i++)); do
  sessions="$(/usr/bin/sudo -u "$user" /usr/bin/env HOME="$home" "$herdr" session list --json 2>/dev/null || true)"
  while IFS= read -r socket; do
    output="$(/usr/bin/sudo -u "$user" /usr/bin/env HOME="$home" HERDR_SOCKET_PATH="$socket" \
      "$herdr" plugin list --plugin nosleep.agent-awake --json 2>/dev/null || true)"
    [[ "$output" == *'"enabled":true'* ]] && exit 0
  done < <(printf '%s\n' "$sessions" | grep -o '"socket_path":"[^"]*"' \
    | sed 's/^"socket_path":"//; s/"$//' || true)
  sleep 1
done
rm -f "$target"
WATCHDOG
ROOT
printf 'nosleep-herdr: installed system permission for %s.\n' "$user"

# Herdr registers a GitHub plugin only after its build commands finish, and
# startup hooks do not run for a live server. Complete startup once registration
# becomes visible; the action receives Herdr's managed state directory.
ready="$(mktemp "${TMPDIR:-/tmp}/nosleep-herdr-ready.XXXXXX")"
rm -f "$ready"
nohup bash "$SCRIPT_DIR/post-install.sh" "$ready" >/dev/null 2>&1 </dev/null &
for ((i = 0; i < 50; i++)); do
  [[ ! -f "$ready" ]] || break
  sleep 0.1
done
[[ -f "$ready" ]] || {
  printf 'nosleep-herdr: unable to start post-install registration.\n' >&2
  exit 1
}
rm -f "$ready"
