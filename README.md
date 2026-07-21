# nosleep

A tiny macOS CLI to keep your Mac awake — even with the lid closed (clamshell mode) — with a built-in auto-off guardrail.

`nosleep` flips the `pmset` switch that keeps the machine running when the lid is shut, and runs `caffeinate` so the display and disk don't idle. A background timer restores normal sleep after a set duration (default 3 hours), so you can't accidentally leave it on forever.

## Why

`caffeinate` alone won't keep a Mac awake once you close the lid — on battery it still sleeps. The setting that actually enables clamshell-without-external-display is `sudo pmset -a disablesleep 1`. `nosleep` wraps that, adds `caffeinate` for the display and disk, and adds a self-expiring timer so it's safe to leave running.

## Requirements

- macOS
- `bash`, `caffeinate`, `pmset` (all ship with macOS)
- `sudo` access — changing `disablesleep` requires it

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
```

`on` and `off` prompt for your password (they run `sudo pmset`). `status` is read-only and needs no password.

Example `status` output:

```
disablesleep : ON  (Mac will not sleep, even with the lid closed)
caffeinate   : running
auto-off in  : 2h 47m (at 04:53 AM)
```

## How it works

- **`sudo pmset -a disablesleep 1`** is the switch that keeps the Mac awake with the lid closed. This is the core of `nosleep on`.
- **`caffeinate -dimsu`** runs alongside it so the display, disk, and system stay awake. It's bounded to the same window and `nohup`'d, so it survives closing the terminal.
- **Auto-off timer:** the re-enable command is spawned inside the same `sudo` call, so it runs as root and restores sleep after the duration without asking for your password again.
- **`off`** cancels the pending timer and restores sleep immediately.

## Caveats

- **Resets on reboot.** macOS sets `disablesleep` back to `0` on restart, so run `nosleep on` again after booting. (This is a feature — it can't get stuck on across reboots.)
- **Heat.** Running heavy workloads with the lid closed traps heat, since the keyboard deck is where it vents. Fine for most tasks; keep an eye on it under sustained load.
- **macOS only.** `pmset` and `caffeinate` are Apple tools.

## License

MIT © 2026 Josh Daniel Bañares
