# NoSleep for Herdr

Automatically keep a Mac awake while Herdr has at least one live agent. Idle,
working, blocked, done, and unknown agents all count until their process exits.

## Install

From GitHub:

```sh
herdr plugin install omsimos/nosleep/herdr-plugin
```

For local development:

```sh
bash herdr-plugin/install.sh
herdr plugin link "$PWD/herdr-plugin"
herdr plugin action invoke start --plugin nosleep.agent-awake
```

Installation asks for `sudo` once. It adds a narrow sudoers rule allowing only
these commands for the current user:

```text
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

The plugin then reacts to Herdr agent lifecycle events and reconciles state every
10 seconds. At or below 20% while on battery power, it restores normal sleep even
if agents remain active. It also runs `caffeinate` and dims the built-in display
while the lid is closed when `nosleep-brightness` is installed or available from
the parent repository.

Do not run a timed `nosleep on` session at the same time; both features control
the same macOS sleep switch.

## Remove

Remove the system permission before uninstalling the plugin:

```sh
herdr plugin pane open --plugin nosleep.agent-awake --entrypoint remove-helper
herdr plugin uninstall nosleep.agent-awake
```

The first command opens an interactive popup for the required sudo prompt.
