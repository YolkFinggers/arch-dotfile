#!/bin/sh
# Single-instance hyprlock launcher, shared by hypridle (lock_cmd + 300s listener) and SUPER+L.
# pidof catches an already-running lock; flock closes the race between two near-simultaneous callers.
pidof hyprlock >/dev/null 2>&1 && exit 0
exec flock -n "${XDG_RUNTIME_DIR:-/tmp}/hyprlock.flock" hyprlock
