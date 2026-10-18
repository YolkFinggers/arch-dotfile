# NEON RAIN — Current State

Updated: 2026-10-18. **M1 prototype accepted for progression; optional hardening deferred by user direction (not fully hardened). M2 implemented, IPC-smoke-tested and confirmed working by the user after the key remap.** M3–M7 are not implemented.

## M2 — City Mode + Herdr tower (accepted by user)

Files: `config/city.json` (Herdr hotspot, artwork px 664,268 136x277, workspace 6), `scripts/city-ctl`, `wallpaper/CityOverlay.qml`, City Mode block + `city*` IPC in `wallpaper/shell.qml`.

Technique: per-output Overlay-layer surface (`neon-rain-city`) in the existing wallpaper instance, same artwork/crop/shader/time as the wallpaper. Mapped only while open; unmapped = no input interception. Workspaces are never switched, so per-monitor workspaces stay; focused window/monitor at open is restored on close. Keyboard Exclusive only on the output focused at open (ESC handler there).

Herdr discovery (real): `herdr session list --json` + `/proc` ancestry of `herdr session attach <name>` clients to Hyprland client PIDs. Click: focus most recent Herdr window via `hl.dispatch(hl.dsp.focus({ window = "address:..." }))`; if none, focus workspace 6 and `hl.exec_cmd("kitty -e herdr session attach <session>", { workspace = "6 silent" })` (form from user's hyprland.lua autostart). Assigned monitor from `hyprctl workspacerules` (6 → HDMI-A-1).

Shortcuts (2026-10-18, user change supersedes earlier SUPER+U City preference): **SUPER+S = City Mode** (persistent in `hypr/.config/hypr/hyprland.lua` line 332, `hl.dsp.exec_cmd("~/.dotfiles/neon-rain/scripts/city-ctl toggle")`, description `neon-rain city-ctl toggle`). Special workspace moved unchanged to **SUPER+U** `toggle_special("magic")` and **SUPER+SHIFT+U** `window.move({ workspace = "special:magic" })`; SUPER+SHIFT+S removed. Backup of exact pre-edit bytes: `run/hyprland.lua.bak-20261018-211018` (sha256 3e29665f…). Hyprland auto-reloaded on save: `configerrors` empty, live table S(city)/U/SHIFT+U, no duplicates. Evidence `tests/results/m2-binds-20261018-*.txt`. `city-ctl bind|unbind` now act only on SUPER+S with our description and refuse otherwise; they never touch U.

Evidence (test-run counts, cap 2 normal / 3 max):
- `tests/results/m2-smoke-20261018-2105*.txt` (run 1): bind ok; toggle open mapped 3 overlay layers, keyboard only on HDMI-A-1, Herdr hotspot eDP-1/DP-1 762,307 156x318, HDMI-A-1 189,547 277x565; toggle close unmapped all, focus restored; dismiss (ESC code path via IPC) restored; activate focused Herdr window.
- `tests/results/m2-smoke2-*.txt` (run 2): tagged bind `ours: true`; opened from DP-1, activate moved focus to Herdr window on HDMI-A-1 (assigned monitor), `verified: true`; workspaces unchanged {eDP-1:1, DP-1:7, HDMI-A-1:6} before/after; initial focus restored.
- Counts: status 1, activate dry-run 2, bind 2, toggle open/close 2, dismiss 1, real activate 2. Launch path executed only as dry-run (Herdr windows exist; no duplicates launched).

User confirmed the rest is working after the SUPER+S remap. This is user acceptance, not an additional automated test run. The absent-window launch path remains dry-run only. `cityCapture` IPC fails (`grabToImage: item has no QML engine` on window contentItem) — no overlay image evidence.

Use: `scripts/neon-rain-proto start` (if not running), then SUPER+S (`scripts/city-ctl bind` only needed if config bind missing). Status: `scripts/city-ctl status`, `scripts/neon-rain-proto ipc cityState`.
Rollback: restore binds with `cp run/hyprland.lua.bak-20261018-211018 ~/.dotfiles/hypr/.config/hypr/hyprland.lua` (Hyprland auto-reloads; this also restores any other edits made since 21:10) or revert just lines 329–332; `scripts/city-ctl unbind` removes only the tagged SUPER+S City bind live; `scripts/neon-rain-proto ipc cityDismiss` if overlay stuck; `scripts/neon-rain-proto stop` removes all neon-rain surfaces. The user-authorized shortcut remap also changed hypr/.config/hypr/hyprland.lua; unrelated existing edits were preserved.

## Current result

The standalone Quickshell prototype renders the approved raw city artwork with animated rain on three wallpaper surfaces. Hermes independently reran the wallpaper-only pixel verification: all three outputs passed animation and cover-crop checks. This verifies rendering into wallpaper captures, not final on-screen appearance or input pass-through.

## Verified evidence

- `tests/results/unit-20261018-203625.txt`: 53 QML tests passed, zero failed; 4 Python analyzer tests passed. Hermes also ran the Python suite separately: 4 passed.
- `tests/results/rain-20261018-203625.txt`: `RESULT: PASS` on eDP-1, DP-1 and HDMI-A-1. Two asynchronous wallpaper-only captures were compared; no application contents are captured.
- eDP-1 and DP-1: 2.230% of pixels changed by more than eight channel levels between captures; mean absolute difference against the plain cover-cropped artwork was 0.77.
- HDMI-A-1: 2.209% changed; mean absolute difference against cover-cropped artwork was 0.86.
- Earlier runtime inspection confirmed 1920×1080 bottom-layer surfaces on eDP-1 and DP-1, and 1080×1920 on HDMI-A-1; artwork Ready on each.
- Balanced profile targets 30 Hz; earlier timer measurement was 29.96 Hz. Timer cadence is not a frame-time benchmark.
- **Protocol check PASS** (`tests/results/protocol-20261018-203733.txt`, log `logs/wayland-debug-20261018-203733.log`). Hermes ran `scripts/verify-protocol.sh 4` with the main prototype stopped and restarted by trap. All 3 neon-rain layer surfaces: `layer=1` (bottom), `keyboard_interactivity=0`, input region with zero `add()` calls (empty, click-through). This is protocol-request evidence from a short separate instance (eco profile). It is not a hands-on click/keyboard test on the desktop.

## Shader-status investigation

The raw Qt `ShaderEffect.status` reports `Uncompiled` despite successful animated wallpaper captures. The original enum mapping was correct; this status alone is not sufficient evidence that drawing failed. The exact internal Qt cause remains unproven. Diagnostics now retain raw status, log and whether Compiled was observed, without claiming rendering success from status alone. Regression coverage is in `tests/qml/tst_diagnostics.qml`.

Relevant additions: `wallpaper/lib/diagnostics.js`, `scripts/verify-rain.sh`, `tests/tools/rain_check.py`, `tests/tools/test_rain_check.py`. Analyzer tests reject static images, mismatched dimensions and stretched portrait passthrough examples. These numerical checks do not replace human appearance review.

## Architecture and scope

- Renderer: `wallpaper/shell.qml`, `RainWallpaper.qml`, compiled rain fragment shader.
- Artwork: `assets/city-raw.png`; approved visual references remain in assets.
- One cover-cropped, bottom-layer surface per output; no stretching to portrait.
- Existing bar and wallpaper daemon remain separate.
- Project edits are confined to neon-rain; existing unrelated Hyprland changes are preserved. No staging or commits.
- Recalled user preference: superseded: City Mode is **SUPER + S** (persistent), special workspace on SUPER+U / SUPER+SHIFT+U (see M2 section).

## Remaining M1 work

- Inspect final on-screen appearance and compare with approved city styleframe.
- Optional: hands-on check that clicks and keys reach windows/desktop under the wallpaper (protocol requests already verified).
- Benchmark follow-ups: stopped-prototype baseline, frame-time/jank data, real power measurement, repeat runs under controlled load.
- Check live scaling/framing, reload/error recovery and long-run memory stability.
- Keep TASKS.md and older architecture/decision caveats reconciled with this newer evidence; previous rule that Uncompiled alone blocks drawing verification is superseded here.

## Performance evidence: bounded profile benchmark

Run 2026-10-18 20:40, PID 477622, `python3 -I scripts/bench-profiles.py` (5 s settle, 60 s measure, 10 s sample interval per phase). Complete; initial overrides (all null, balanced default) restored and confirmed afterwards.

- Raw samples: `tests/results/bench-20261018-204052.jsonl`. Summary: `tests/results/bench-20261018-204052.json`. Console: `tests/results/bench-console-20261018-204052.txt`.
- `smoke-bench-20261018-204030.*` is a 3 s smoke run of the script only; do not use it as data.

| Phase | CPU % one core (60 s) | 10 s intervals | RSS start→end kB | framesSwapped/s eDP-1 / DP-1 / HDMI-A-1 | i915 render occupancy |
|---|---|---|---|---|---|
| eco (15 fps) | 6.42 | 5.75–6.73 | 271124→271104 | 14.92 / 14.92 / 14.92 | 2.80% |
| balanced (30 fps) | 11.17 | 10.12–12.05 | 271108→271164 | 30.32 / 30.32 / 30.32 | 6.36% |
| smooth (60 fps) | 21.23 | 19.43–22.63 | 271200→271112 | 58.80 / 58.70 / 58.80 | 16.01% |
| static reduced motion | 0.00 | 0.00 all | 271136→271192 | 0 / 0 / 0 | 0.00% |

Method and limits:
- CPU from `/proc/PID/stat` utime+stime ticks (CLK_TCK 100) over `time.monotonic_ns()` intervals. In the static phase, CPU stayed under one tick per 10 s window.
- Render occupancy = delta of `drm-engine-render` ns in `/proc/PID/fdinfo`, divided by wall time. Entries are deduplicated by `(drm-pdev, drm-client-id)`. fds 25/26/27/28 are one client (0000:00:02.0/355) and are counted once, not summed.
- Render occupancy is this process's busy time on the Intel render engine only. It is **not** global GPU utilization and **not** a complete power measurement.
- No stopped-prototype baseline was taken in this run. Desktop load was not controlled. IPC status polls (one per 10 s) add a small cost.
- Smooth presents about 58.7–58.8 frames/s, not 60. This was not investigated (timer interval rounding to 17 ms is a likely cause).
- RSS stayed flat (about 271 MB) during the 4.3 min run. This is not a long-run stability test (T6).

## Reproduce

Run from `~/.dotfiles/neon-rain`:

```bash
./tests/run-unit.sh
python -I tests/tools/test_rain_check.py -v
bash scripts/verify-rain.sh 2.5
./scripts/neon-rain-proto status
python3 -I scripts/bench-profiles.py   # about 4.5 min, needs the prototype running
```

Stop only this prototype:

```bash
./scripts/neon-rain-proto stop
```

Start it again (no permanent autostart):

```bash
./scripts/neon-rain-proto start
```

## Next concrete action

User manual check: press SUPER+S (city appears, rain live), hover Herdr tower (card shows WS 6 → HDMI-A-1, running sessions/windows), press ESC (previous focus back), SUPER+S then click tower from DP-1 (focus lands on Herdr on HDMI-A-1). No more automated M2 runs without user approval (bind/toggle/activate at 2 of 3 cap); also check SUPER+U / SUPER+SHIFT+U special workspace. Then M3.
