#!/bin/sh
# Single-instance lock entry point for SUPER+L (manual only: hypridle is masked, so there is
# no automatic idle lock and `loginctl lock-session` has no handler).
# hyprlock runs in hyprlock.service, not as a child of the caller, so the caller's cgroup
# cannot kill an active lock. systemd keeps the unit single-instance;
# pidof skips a hyprlock started outside the unit.
pidof hyprlock >/dev/null 2>&1 && exit 0
# Refresh the session environment so the unit talks to the current Hyprland instance.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
	systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
fi
exec systemctl --user start hyprlock.service
