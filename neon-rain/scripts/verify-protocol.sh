#!/usr/bin/env bash
# Protocol-level check of the wallpaper's layer, input and keyboard behaviour.
#
# Runs a SHORT, separate prototype instance with WAYLAND_DEBUG=client for a few seconds,
# then analyses the requests Qt actually sent to Hyprland:
#   - every neon-rain layer surface is created on layer 1 (bottom)
#   - keyboard_interactivity is 0 (none) or never set (protocol default 0)
#   - the surface's input region is a wl_region with zero add() calls (empty => click-through)
#
# The main prototype must be stopped first (Quickshell --no-duplicate would refuse a second
# copy of the same config). Only the PID this script starts is ever signalled.
#
# Usage: scripts/verify-protocol.sh [seconds=4]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTO="$ROOT/scripts/neon-rain-proto"
RUN_SECONDS="${1:-4}"
STAMP="$(date +%Y%m%d-%H%M%S)"
RAW="$ROOT/logs/.wayland-debug-raw-$STAMP"
OUT="$ROOT/logs/wayland-debug-$STAMP.log"

if "$PROTO" status >/dev/null 2>&1; then
    echo "main prototype is running; stop it first: $PROTO stop" >&2
    exit 1
fi

DISCOVERED="$("$PROTO" discover)"
SIG="$(sed -n 's/^hyprland_instance_signature=//p' <<<"$DISCOVERED")"
WL="$(sed -n 's/^wayland_display=//p' <<<"$DISCOVERED")"
RT="$(sed -n 's/^xdg_runtime_dir=//p' <<<"$DISCOVERED")"
mkdir -p "$ROOT/logs"

# env -i execs quickshell, so $! is quickshell's own PID.
env -i HOME="$HOME" USER="$USER" PATH=/usr/bin:/bin LANG=C.UTF-8 \
    XDG_RUNTIME_DIR="$RT" WAYLAND_DISPLAY="$WL" HYPRLAND_INSTANCE_SIGNATURE="$SIG" \
    QT_QPA_PLATFORM=wayland NEON_RAIN_PROFILE=eco WAYLAND_DEBUG=client \
    /usr/bin/quickshell --path "$ROOT/wallpaper" --no-duplicate --no-color \
    >"$RAW" 2>&1 </dev/null &
QS_PID=$!
sleep "$RUN_SECONDS"
kill -TERM "$QS_PID" 2>/dev/null || true
wait "$QS_PID" 2>/dev/null || true

# Keep only the protocol requests that matter; drop the raw trace.
grep -E 'create_region|wl_region#[0-9]+\.(add|subtract)|set_input_region|get_layer_surface|set_keyboard_interactivity|zwlr_layer_surface_v1#[0-9]+\.set_layer' \
    "$RAW" >"$OUT" || true
rm -f "$RAW"

echo "protocol log: $OUT ($(wc -l <"$OUT") lines)"
python3 -I - "$OUT" <<'PY'
import re, sys

regions = {}         # wl_region id -> number of add() calls
surface_region = {}  # wl_surface id -> last input region id ("nil" = infinite)
layers = {}          # layer_surface id -> (wl_surface id, layer, namespace)
kbd = {}
for line in open(sys.argv[1]).read().splitlines():
    if not " -> " in line:
        continue  # only client requests
    if m := re.search(r'create_region\(new id wl_region#(\d+)\)', line):
        regions[m[1]] = 0
    elif m := re.search(r'wl_region#(\d+)\.add\(', line):
        regions[m[1]] = regions.get(m[1], 0) + 1
    elif m := re.search(r'wl_surface#(\d+)\.set_input_region\((?:wl_region#(\d+)|(nil))\)', line):
        surface_region[m[1]] = m[2] or "nil"
    elif m := re.search(r'get_layer_surface\(new id zwlr_layer_surface_v1#(\d+), wl_surface#(\d+), [^,]+, (\d+), "([^"]*)"\)', line):
        layers[m[1]] = (m[2], int(m[3]), m[4])
    elif m := re.search(r'zwlr_layer_surface_v1#(\d+)\.set_keyboard_interactivity\((\d+)\)', line):
        kbd[m[1]] = int(m[2])

ok, found = True, 0
for ls, (surf, lvl, ns) in layers.items():
    if ns != "neon-rain-wallpaper":
        continue
    found += 1
    reg = surface_region.get(surf, "unset")
    adds = regions.get(reg) if reg not in ("nil", "unset") else None
    k = kbd.get(ls)
    empty = adds == 0
    print(f"layer_surface#{ls} wl_surface#{surf}: layer={lvl} "
          f"keyboard_interactivity={'unset(default 0)' if k is None else k} "
          f"input_region={reg} adds={adds} -> {'EMPTY (click-through)' if empty else 'NOT EMPTY'}")
    ok &= lvl == 1 and empty and k in (None, 0)
print("RESULT:", "PASS" if ok and found else "FAIL", f"({found} wallpaper surfaces)")
sys.exit(0 if ok and found else 1)
PY
