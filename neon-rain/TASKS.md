# NEON RAIN — Tasks

## Accepted milestones

- [x] M1: living-wallpaper prototype, accepted for progression. Approved artwork plus GPU rain, aspect-preserving crop on three outputs, configurable profiles and reduced motion.
- [x] Rendering evidence: two-time wallpaper-only captures and crop checks passed. Raw ShaderEffect Uncompiled status is not conclusive failure; diagnostics retain the raw status and log.
- [x] Normal wallpaper Wayland protocol: Bottom layer, empty input region, no keyboard focus on all three surfaces.
- [x] Four-profile benchmark: 60 seconds each, process CPU/RSS, frame callbacks, deduplicated per-process Intel render counters. Balanced restored; no stopped baseline or power measurement claimed.
- [x] M2: City Mode overlay with Herdr hotspot, discovery and existing-window focus; IPC smoke runs 1–2, followed by user confirmation that the rest works after remapping.
- [x] Persistent shortcuts: SUPER+S City Mode; SUPER+U special workspace magic; SUPER+SHIFT+U move window to special:magic.
- [x] Test budget: two runs acceptable, three maximum per test across all agents; further confirmation requires user check. Do not restart successful wallpaper tests.

## Next — M3 configurable building system

- [ ] Add data-driven destinations for Nvim, Paperclip, Zen, Chrome, Infrastructure and Lazygit, reusing existing Herdr architecture.
- [ ] Lazygit repository selector with actual repositories, existing-window reuse and conflict-checked independent shortcut.
- [ ] Trustworthy running/idle/busy/error indicators only where supported by real integrations.

## Deferred hardening / known limits

- [ ] Fix optional cityCapture helper: grabToImage reports item has no QML engine. User acceptance does not depend on capture helper.
- [ ] No-existing-Herdr-window launch path: dry-run only; do not launch duplicates just to test.
- [ ] Optional longer stability, stopped baseline, frame-time/power observations and reload/error hardening. Not prerequisites for M3; no soak observer should be launched without a new request.
- [ ] Wallpaper startup/supervision is not installed. Existing bar and hyprpaper are preserved.

## Later milestones

- [ ] M4 Quickshell dropdown dashboard.
- [ ] M5 borders/animations polish.
- [ ] M6 matching lock screen and portrait utility layout.
- [ ] M7 integration/reliability and installation/rollback documentation.

## Existing evidence

Local raw evidence is under tests/results/ and logs/ (Git-ignored). Reproducible scripts and test sources are versioned; summarized findings and caveats are in STATE.md.
