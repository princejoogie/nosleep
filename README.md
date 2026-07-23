# nosleep

[![shellcheck](https://github.com/omsimos/nosleep/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/omsimos/nosleep/actions/workflows/shellcheck.yml)

A tiny macOS CLI that keeps your Mac awake with the lid closed (clamshell mode) — so long tasks like agent runs, builds, or downloads keep going — while switching off the hidden display backlight and retaining a built-in auto-off guardrail.

`caffeinate` alone won't do this: on battery a Mac still sleeps once you close the lid. The switch that actually enables clamshell-without-external-display is `sudo pmset -a disablesleep 1`. `nosleep` wraps that, runs `caffeinate` so the display and disk don't idle, dims the built-in display to zero while the lid is closed, and arms a timer that restores normal sleep after a set duration (default 3h) so you can't leave it on forever.

## Install

With npm:

```sh
npm install -g nosleep-cli
```

With Homebrew:

```sh
brew install omsimos/tap/nosleep
```

Or from source:

```sh
xcode-select --install
git clone https://github.com/omsimos/nosleep.git
cd nosleep
make install
```

The Xcode Command Line Tools provide Swift for the bundled brightness helper. `make install` symlinks `nosleep` and copies its private `nosleep-brightness` helper into `~/.local/bin` (make sure that's on your `PATH`). Install elsewhere with `PREFIX`:

```sh
make install PREFIX=/usr/local   # installs into /usr/local/bin (may need sudo)
```

Or just symlink it yourself:

```sh
ln -sf "$PWD/nosleep" ~/.local/bin/nosleep
install -m 755 "$PWD/nosleep-brightness" ~/.local/bin/nosleep-brightness
```

## Usage

```sh
nosleep on          # disable sleep for 3h (default), then auto-restore
nosleep on 90m      # custom window — accepts 3h, 90m, 45s, or a bare number (hours)
nosleep off         # restore normal sleep immediately
nosleep status      # show current state and time remaining
nosleep --help      # usage
```

`on` and `off` run `sudo pmset` and may prompt for your password. `status` is read-only and needs no password. Running `on` again while already active just refreshes the window with the new duration.

Example `status` output:

```
disablesleep : ON  (Mac will not sleep, even with the lid closed)
caffeinate   : running
lid watcher  : running
auto-off in  : 2h 47m (at 04:53 AM)
```

## How it works

- **`sudo pmset -a disablesleep 1`** is the switch that keeps the Mac awake with the lid closed. This is the core of `nosleep on`.
- **`caffeinate -dimsu`** runs alongside it so the display, disk, and system stay awake. It's bounded to the same window and `nohup`'d, so it survives closing the terminal.
- **Lid watcher:** `ioreg` reports `AppleClamshellState`. The watcher caches the built-in display ID while the lid is open, so it can save the current brightness and set that display to zero even after macOS removes it from the online display list. It restores the saved value when the lid opens, `nosleep off` runs, or the timer expires.
- **Brightness helper:** the bundled Swift script uses macOS's private `DisplayServices` framework to control the built-in display. Because this is a private API, a future macOS release could require an update.
- **Auto-off timer:** the re-enable command is spawned inside the same `sudo` call, so it runs as root and restores sleep after the duration without asking for your password again. It waits briefly for the user-session lid watcher to restore brightness before re-enabling lid sleep. This means a short-lived root-owned `sleep` process lingers until it fires (or until `nosleep off` kills it).
- **`off`** restores brightness, cancels the pending timer, and restores normal sleep immediately.
- **State** lives in `$XDG_STATE_HOME/nosleep` (defaults to `~/.local/state/nosleep`): PID files for `caffeinate`, the lid watcher, and the timer; the cached display ID and saved brightness; and the scheduled auto-off time. `status` cleans up stale state on its own (e.g. after a reboot).
- **Reboots reset it.** macOS clears `disablesleep` on restart, so re-run `nosleep on` after booting — and it can never get stuck on across reboots.
- **Heat.** Heavy workloads with the lid closed trap heat, since the keyboard deck is where it vents — keep an eye on it under sustained load.

## License

MIT
