# NEON RAIN — Architecture (M1/M2)

Scope: M1 wallpaper and M2 City Mode are implemented. M3+ are not built. City Mode uses same-artwork QML overlays, Python city-ctl, JSON hotspots, Quickshell IPC and Hyprland Lua/IPC. SUPER+S opens City Mode; SUPER+U and SUPER+SHIFT+U control special:magic. See STATE.md for accepted behavior and verification limits.

## Layout

```
neon-rain/
  GOAL.md                     mission, visual source of truth, milestones M0–M7
  assets/
    city-raw.png              approved raw city artwork (rendered by the wallpaper)
    city-reference.png        styleframe reference
    hyprlock-reference.png    lock screen styleframe reference (M6)
  config/wallpaper.json       user config: profile, fps, reducedMotion, rain, per-output crop focus
  wallpaper/                  Quickshell shell dir (quickshell --path wallpaper)
    shell.qml                 ShellRoot: config, settings, shared timer, Variants per screen, IPC
    RainWallpaper.qml         PanelWindow per output: artwork Image + rain ShaderEffect
    lib/geometry.js           pure cover-crop maths
    lib/profiles.js           pure profile table + settings resolution and validation
    shaders/rain.frag         GLSL 440 rain shader source
    shaders/rain.frag.qsb     compiled shader (qsb --qt6), built by neon-rain-proto compile
  scripts/
    neon-rain-proto           start/stop/status/logs/ipc/compile/discover control script
    hyprlayers.py             filters `hyprctl layers -j` by PID
    verify-protocol.sh        WAYLAND_DEBUG protocol check of layer/input/keyboard
  tests/
    run-unit.sh               headless qmltestrunner (QT_QPA_PLATFORM=offscreen)
    qml/tst_geometry.qml, tst_profiles.qml, tst_config.qml
    results/                  unit outputs, captures (live/), screenshots (screens/)
  logs/                       prototype logs, latest.log symlink
  run/prototype.pid           PID of the running prototype
```

## Runtime model

- **Separate Quickshell instance.** Started with `quickshell --path <repo>/neon-rain/wallpaper --no-duplicate`. It is independent of the bar in `~/.config/quickshell`, so starting or stopping it does not affect the bar.
- **One surface per output.** `Variants { model: Quickshell.screens }` creates a `RainWallpaper` (`PanelWindow`) per screen.
- **Layer and input.** `WlrLayer.Bottom` (above hyprpaper's Background, below windows and the bar). Namespace `neon-rain-wallpaper`. `exclusionMode: Ignore`. Empty input region (`mask: Region {}`) for click-through. `WlrKeyboardFocus.None`.
- **Rendering.** A hidden `Image` loads `assets/city-raw.png`. A `ShaderEffect` that fills the window samples it through `rain.frag.qsb`. The shader applies the cover crop via `uvScale`/`uvOffset`, then adds 1–4 procedural rain layers in output-pixel space. The nearest layer refracts the artwork slightly (`distortion`). Backend observed: OpenGL QRhi on Mesa Intel.
- **Timing.** One shared `Timer` in `shell.qml` updates `time` at `settings.frameIntervalMs`. Time wraps at 600 s to keep float32 precision. All outputs read the same `time`, so they animate in lockstep and only re-render on ticks. With reduced motion `static`, the timer stops and one frame remains.
- **Crop.** `Geometry.coverCrop(imgW, imgH, viewW, viewH, focusX, focusY)` gives an aspect-preserving cover crop (never stretched) with per-output focus from `config.outputs[<name>]`, falling back to `default`, then centre. Portrait HDMI-A-1 crops width.

## Settings resolution (`lib/profiles.js`)

Precedence, highest first: runtime IPC override > environment (`NEON_RAIN_PROFILE`, `NEON_RAIN_FPS`, `NEON_RAIN_REDUCED_MOTION`) > `config/wallpaper.json` > defaults.

| Profile | fps | layers | density | distortion |
|---|---|---|---|---|
| eco | 15 | 2 | 0.45 | 0.0 |
| balanced (default) | 30 | 3 | 0.6 | 0.5 |
| smooth | 60 | 4 | 0.7 | 1.0 |

- fps override range 1..120, clamped; non-integers are rejected with a warning.
- Reduced motion always beats an fps override. Style `static` stops animation (no timer, ≤2 layers, no distortion). Style `slow` uses 10 fps, 1 layer, 0.35 density, 0.35× speed.
- `rain.intensity` is clamped to 0..2, `rain.speed` to 0.1..3.
- Invalid values fall back and go into `warnings`, which are logged.
- `config/wallpaper.json` is watched (`FileView watchChanges`). A parse error keeps the previous config.

## IPC (`quickshell ipc --pid <pid> call neonrain <fn>`, wrapped by `neon-rain-proto ipc`)

- `status`: settings, overrides, uptime, timer ticks, `measuredTickHz`, per-surface `describe()` (size, artwork size/status, shader status, `framesSwapped`, crop).
- `setProfile NAME`, `setFps N`, `setReducedMotion true|false`, `clearOverrides`.
- `capture TAG`: grabs only the wallpaper item (not windows or bar) to `tests/results/live/<sanitised-tag>-<output>.png`. The path is fixed and the tag is sanitised.

Shader diagnostics: `describe()` reports `shader` from `lib/diagnostics.js`. The mapping follows Qt's enum (Compiled 0, Uncompiled 1, Error 2; `qquickshadereffect_p.h`, Qt 6.12), and `tests/qml/tst_diagnostics.qml` checks it against `ShaderEffect.*`. The raw Qt status is not a drawing signal: it reads `Uncompiled` while rain renders (DECISIONS D13). Rendering proof: `scripts/verify-rain.sh` with `tests/tools/rain_check.py`.

## Control script safety (`scripts/neon-rain-proto`)

- `discover` accepts a Hyprland instance only if its lock-file PID is a live `Hyprland` owned by the user, both sockets exist, and `hyprctl` answers. It refuses if there are several instances unless `NEON_RAIN_HYPR_SIG` is set.
- `start` runs `setsid env -i` with an allow-listed environment (no inherited tokens). It logs to `logs/`, writes `run/prototype.pid`, and waits up to 10 s for a `neon-rain-wallpaper` layer.
- `stop` signals only the PID file's process, and only if its cmdline contains `--path <repo>/neon-rain/wallpaper`. SIGTERM, then SIGKILL after 5 s with identity re-checked.
- The script never touches the bar, hyprpaper, Hyprland config or other processes.

## Not yet in the architecture

Wallpaper startup is still manual; no wallpaper supervision/restart service is installed. M2 has a Herdr hotspot and persistent SUPER+S binding; additional buildings, repository selection and dropdown are future work. Hyprpaper remains underneath.
