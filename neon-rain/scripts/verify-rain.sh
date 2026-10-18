#!/usr/bin/env bash
# Proves the rain shader is drawing on every output, using wallpaper-only captures
# (ShaderEffect.grabToImage via IPC: never windows or the bar). Takes capture A, waits,
# takes capture B, then runs tests/tools/rain_check.py (animation + cover-crop checks).
#
# Usage: scripts/verify-rain.sh [gap-seconds]   (default 2.5; needs the prototype running)
# Writes tests/results/rain-<stamp>.txt and tests/results/live/rain<stamp>{A,B}-<output>.png
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAP="${1:-2.5}"
STAMP="$(date +%Y%m%d-%H%M%S)"
TAG="rain${STAMP//-/}"
LIVE="$ROOT/tests/results/live"
OUT="$ROOT/tests/results/rain-$STAMP.txt"
STATUS="$ROOT/tests/results/rain-$STAMP-status.json"
PROTO="$ROOT/scripts/neon-rain-proto"

# grabToImage saves asynchronously after the IPC call returns: wait until each PNG decodes.
wait_pngs() {
    local files="$1" i
    for i in $(seq 1 50); do
        if python3 -I -c 'import sys; from PIL import Image
for p in sys.argv[1:]: Image.open(p).load()' $files 2>/dev/null; then
            return 0
        fi
        sleep 0.2
    done
    echo "captures not readable: $files" >&2
    return 1
}
files_of() { python3 -I -c 'import json,sys; print(" ".join(json.load(sys.stdin)["files"]))'; }

"$PROTO" ipc status >"$STATUS"
a=$("$PROTO" ipc capture "${TAG}A")
wait_pngs "$(files_of <<<"$a")"
sleep "$GAP"
b=$("$PROTO" ipc capture "${TAG}B")
wait_pngs "$(files_of <<<"$b")"

{
    echo "# verify-rain $STAMP gap=${GAP}s"
    echo "# capture A: $a"
    echo "# capture B: $b"
    set +e
    python3 -I "$ROOT/tests/tools/rain_check.py" "$ROOT/assets/city-raw.png" "$STATUS" \
        "$LIVE/${TAG}A" "$LIVE/${TAG}B"
    rc=$?
    set -e
} >"$OUT" 2>&1 || true
cat "$OUT"
echo "report: $OUT"
grep -q '^RESULT: PASS' "$OUT"
