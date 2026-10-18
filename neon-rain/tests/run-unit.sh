#!/usr/bin/env bash
# Headless unit tests: geometry/profile maths and the shipped config, in the real QML JS
# engine (qmltestrunner). Needs no compositor and never touches the running prototype.
#
# Usage: tests/run-unit.sh            (writes tests/results/unit-<stamp>.txt)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/tests/results/unit-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$ROOT/tests/results"

# Allow-listed env; offscreen platform so no window is ever shown.
set +e
env -i HOME="$HOME" PATH=/usr/bin:/bin LANG=C.UTF-8 \
    QT_QPA_PLATFORM=offscreen QML_XHR_ALLOW_FILE_READ=1 QT_FORCE_STDERR_LOGGING=1 \
    /usr/lib/qt6/bin/qmltestrunner -input "$ROOT/tests/qml" >"$OUT" 2>&1
rc=$?
# Pixel-proof analyzer (tests/tools/rain_check.py) on synthetic images.
echo "# python: tests/tools/test_rain_check.py" >>"$OUT"
env -i HOME="$HOME" PATH=/usr/bin:/bin LANG=C.UTF-8 \
    python3 -I "$ROOT/tests/tools/test_rain_check.py" -v >>"$OUT" 2>&1
prc=$?
set -e

grep -E '^(FAIL|XFAIL|XPASS|SKIP)|Actual|Expected|Loc:|^(FAIL|ERROR):' "$OUT" || true
grep -E '^Totals|^Ran [0-9]+ tests|^(OK|FAILED)' "$OUT"
echo "full output: $OUT"
[ "$rc" -eq 0 ] && [ "$prc" -eq 0 ]
