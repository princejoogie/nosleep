# nosleep

[![shellcheck](https://github.com/joshxfi/nosleep/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/joshxfi/nosleep/actions/workflows/shellcheck.yml)

A tiny macOS CLI that keeps your Mac awake with the lid closed (clamshell mode) — so long tasks like agent runs, builds, or downloads keep going — with a built-in auto-off guardrail.

`caffeinate` alone won't do this: on battery a Mac still sleeps once you close the lid. The switch that actually enables clamshell-without-external-display is `sudo pmset -a disablesleep 1`. `nosleep` wraps that, runs `caffeinate` so the display and disk don't idle, and arms a timer that restores normal sleep after a set duration (default 3h) so you can't leave it on forever. Everything it uses ships with macOS — nothing to install.

## Install

```sh
git clone https://github.com/joshxfi/nosleep.git
cd nosleep
make install
```

`make install` symlinks `nosleep` into `~/.local/bin` (make sure that's on your `PATH`). Install elsewhere with `PREFIX`:

```sh
make install PREFIX=/usr/local   # symlinks into /usr/local/bin (may need sudo)
```

Or just symlink it yourself:

```sh
ln -sf "$PWD/nosleep" ~/.local/bin/nosleep
```

## Usage

```sh
nosleep on          # disable sleep for 3h (default), then auto-restore
nosleep on 90m      # custom window — accepts 3h, 90m, 45s, or a bare number (hours)
nosleep off         # restore normal sleep immediately
nosleep status      # show current state and time remaining
nosleep --help      # usage
nosleep --version   # version
```

`on` and `off` run `sudo pmset` and may prompt for your password. `status` is read-only and needs no password. Running `on` again while already active just refreshes the window with the new duration.

Example `status` output:

```
disablesleep : ON  (Mac will not sleep, even with the lid closed)
caffeinate   : running
auto-off in  : 2h 47m (at 04:53 AM)
```

## How it works

- **`sudo pmset -a disablesleep 1`** is the switch that keeps the Mac awake with the lid closed. This is the core of `nosleep on`.
- **`caffeinate -dimsu`** runs alongside it so the display, disk, and system stay awake. It's bounded to the same window and `nohup`'d, so it survives closing the terminal.
- **Auto-off timer:** the re-enable command is spawned inside the same `sudo` call, so it runs as root and restores sleep after the duration without asking for your password again. This means a short-lived root-owned `sleep` process lingers until it fires (or until `nosleep off` kills it).
- **`off`** cancels the pending timer and restores sleep immediately.
- **State** lives in `$XDG_STATE_HOME/nosleep` (defaults to `~/.local/state/nosleep`): PID files for the `caffeinate` and timer processes, plus the scheduled auto-off time. `status` cleans up stale state on its own (e.g. after a reboot).
- **Reboots reset it.** macOS clears `disablesleep` on restart, so re-run `nosleep on` after booting — and it can never get stuck on across reboots.
- **Heat.** Heavy workloads with the lid closed trap heat, since the keyboard deck is where it vents — keep an eye on it under sustained load.

## License

MIT
