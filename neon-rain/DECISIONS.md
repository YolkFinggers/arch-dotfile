# NEON RAIN — Decisions

Decisions as reflected in the current code. Status: accepted unless marked otherwise.

## D1 Separate Quickshell instance for the wallpaper
The wallpaper runs as `quickshell --path neon-rain/wallpaper`, not inside the bar config in `~/.config/quickshell`.
**Why:** Starting, stopping or crashing the prototype must never affect the bar. It also keeps M1 reversible without touching desktop config.

## D2 Render the approved raw artwork; rain is a shader overlay
`assets/city-raw.png` is sampled directly and rain is added procedurally in `rain.frag`. The city is not rebuilt.
**Why:** GOAL.md requires a faithful, recognisable artwork and says "avoid rebuilding the city from scratch".

## D3 Bottom layer, empty input region, no keyboard focus
`WlrLayer.Bottom`, `mask: Region {}`, `WlrKeyboardFocus.None`, `exclusionMode: Ignore`.
**Why:** The surface sits above hyprpaper and below all windows and the bar, and must never steal clicks or keys. Protocol-level proof is pending (TASKS T3).

## D4 Cover crop, never stretch, per-output focus
The crop is computed in pure JS (`lib/geometry.js`) and applied in the shader via `uvScale`/`uvOffset`. Focus comes from config per output name.
**Why:** It handles landscape and portrait (HDMI-A-1 1080x1920) without distortion, and the pure function is unit-testable headlessly.

## D5 One shared timer, explicit fps profiles
A single `Timer` drives `time` for all outputs. Profiles are eco 15 / balanced 30 (default) / smooth 60 fps.
**Why:** Rendering happens only on ticks (bounded GPU cost), and all screens stay in sync. Cost is chosen by the user, not tied to vsync.

## D6 Settings precedence: IPC > env > config > defaults, with validation and warnings
**Why:** Runtime tuning without restarts, reproducible env-based tests, and invalid input that is reported instead of silently misbehaving.

## D7 Reduced motion beats fps overrides; default style is `static`
**Why:** Accessibility preference must win. With `static`, rain stays visible but the timer stops, so no animation cost remains.

## D8 Time wraps at 600 s
**Why:** Keeps `time * px/s` small enough for float32 precision in the shader over long uptimes.

## D9 Scoped, allow-listed process control
`neon-rain-proto` uses `env -i` with an allow-listed environment and verifies Hyprland instance identity. Stop acts only on a PID whose cmdline matches this repo's wallpaper path. SIGKILL comes only after re-verification.
**Why:** It must never signal unrelated processes or leak inherited tokens into logs.

## D10 Captures include only the wallpaper item
IPC `capture` uses `grabToImage` on the ShaderEffect and writes to a fixed directory with a sanitised tag.
**Why:** Test evidence must not leak window or application contents, and IPC must not be able to write arbitrary paths.

## D11 Headless unit tests with qmltestrunner (offscreen)
**Why:** The logic is verified in the real QML JS engine without a compositor and without touching the running prototype.

## D12 No performance claims without measurements
**Status:** Process rule. One 10 s sample (9.9% of one core CPU, RSS 317152 kB) is recorded in STATE.md as informal only. Global GPU utilization is not attributed to the prototype. M1 benchmarking stays open (TASKS T4).

## D13 Shader rendering is proved by pixels, not by `ShaderEffect.status`
**Status:** Accepted 2026-10-18. Supersedes the earlier rule "rain is not verified while shader status reads `Uncompiled`".
Qt's `ShaderEffect.status` reads `Uncompiled` on every live surface while the custom shader demonstrably draws. Evidence is in STATE.md. IPC `status` therefore reports `shader: {qtStatus, health, compiledSeen, log, note}`. `health` is `error` only for `ShaderEffect.Error`. Rendering proof is `scripts/verify-rain.sh`: two wallpaper-only captures per output, an animation diff, and a cover-crop match.
**Why:** The raw value fell back from `Compiled` to `Uncompiled` without any failure (first launch logged `eDP-1: shader ready`, and IPC later read `Uncompiled`). Treating it as failure, or as success, would both be misleading.

## D14 No desktop integration in M1 yet
No Hyprland config, autostart, bar or hyprpaper changes have been made for the wallpaper.
**Why:** Keep the prototype reversible. Integration needs explicit approval and comes after M1 verification.

## D15 City Mode shortcut is `SUPER + U` (supersedes GOAL.md `SUPER + S`)
**Status:** Accepted user preference, recalled 2026-10-18. Not implemented yet.
GOAL.md still says `SUPER + S` in several places. Wherever GOAL.md says `SUPER + S` for City Mode, read `SUPER + U`. When the shortcut is built (M2+), check `SUPER + U` for conflicts first. Do not add any keybinding before that milestone is approved.
**Why:** The user stated this preference. GOAL.md is the original brief and is left unedited.
