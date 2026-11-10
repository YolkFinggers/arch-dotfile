# Neon Rain session startup

Neon Rain runs under the `neon-rain.service` systemd user unit. The unit is symlinked from this folder into `~/.config/systemd/user/`.

The `hyprland.start` hook in `hyprland.lua` imports the compositor environment, clears a previous service failure and restarts the unit. It does not start at machine boot or rely on `graphical-session.target`, which is inactive in this setup. Restarting at session startup also replaces any surviving instance from the previous session.

The failure reset is best-effort (`{ systemctl --user reset-failed neon-rain.service || true; }`). On a fresh login the unit is not enabled and not yet loaded, so `reset-failed` exits 1 with `Unit neon-rain.service not loaded.`. In a plain `&&` chain that exit code skips the restart, and the service stays inactive with no journal entries. Do not chain `reset-failed` with `&&`. The environment import remains a hard gate for the restart.

The service uses `Type=forking` with the existing launcher's PID file. The launcher discovers the live compositor, compiles stale shaders and starts the detached Quickshell process; systemd then tracks that exact process via `run/prototype.pid`. This retains the existing City Mode IPC path. A failure triggers a restart after three seconds, limited to three starts per minute. Crash recovery is configured, not fault-injection tested.

## Daily commands

```sh
systemctl --user restart neon-rain.service
systemctl --user stop neon-rain.service
systemctl --user start neon-rain.service
systemctl --user status neon-rain.service
journalctl --user -u neon-rain.service -b
```

Use systemctl for lifecycle commands while installed. Do not run a second bare Quickshell wallpaper process or manually stop the supervised process. Read-only controller commands still work:

```sh
~/.dotfiles/neon-rain/scripts/neon-rain-proto status
~/.dotfiles/neon-rain/scripts/neon-rain-proto ipc cityState
~/.dotfiles/neon-rain/scripts/city-ctl bind-status
```

Detailed renderer logs remain under `neon-rain/logs/latest.log`. City Mode starts closed. Hyprpaper remains as the static background fallback. Neither the Quickshell bar nor unrelated applications are restarted.

## Installation

```sh
ln -s ~/.dotfiles/neon-rain/systemd/neon-rain.service ~/.config/systemd/user/neon-rain.service
systemctl --user daemon-reload
```

When migrating an already-running manual instance, stop it with `neon-rain-proto stop` before starting the service. Do not enable this unit: its startup owner is the Hyprland hook.

## Rollback

Remove only the Neon Rain `hl.exec_cmd` block and its comment from the Hyprland startup hook, then:

```sh
systemctl --user stop neon-rain.service
rm ~/.config/systemd/user/neon-rain.service
systemctl --user daemon-reload
```

Manual operation is then available with `neon-rain-proto start` / `stop`.

## Verification and limits

Verified live: unit syntax, active/running service, MainPID equals the controller PID, exactly one wallpaper process, wallpaper IPC on all three connected outputs, closed City Mode, owned Super+S binding, no Hyprland config errors, and unchanged bar PID.

A fresh-login startup, deliberate crash recovery, logout lifecycle and monitor hotplug were not exercised. The unit is not tied to a session-stop target; without an active graphical-session target, logout cleanup depends on the Wayland client exiting when the compositor disappears. A subsequent Hyprland start resets failure state and restarts it. Existing monitor-hotplug limitations are unchanged.
