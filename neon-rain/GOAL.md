# GOAL: NEON RAIN — Build a Living, Interactive Hyprland Desktop

## Mission

Design, implement, test, and refine a production-quality, highly customized Arch Linux + Hyprland desktop environment called **NEON RAIN**.

Transform the existing desktop into a beautiful, responsive, immersive cyberpunk environment featuring:

- A live, animated, interactive cyberpunk city wallpaper.
- Customizable buildings mapped to real workspaces, applications, and actions.
- A `SUPER + S` city navigation system.
- A custom Quickshell dropdown dashboard.
- Sharp, precise Hyprland animations and window styling.
- A matching Hyprlock Neon Rain lock screen.
- Proper horizontal and vertical monitor support.
- Live application, agent, Git, and background-process status indicators.

**The deliverable must be a functioning desktop, not a mockup, video, or static screenshots.**

Use Claude Code as an engineering executor where appropriate. Hermes owns planning, coordination, integration, verification, and tracking progress toward the goal.

## 1. Visual Source of Truth

The two selected styleframes (customized city wallpaper and matching Neon Rain Hyprlock) are the authoritative visual references. Ask for their paths if they are not accessible; do not invent substitute files.

Preserve:
- Futuristic, rain-soaked cyberpunk metropolis.
- Huge violet moon and atmospheric clouds.
- Elevated railways and distant futuristic vehicles.
- Purple neon-lit skyscrapers.
- Reflective water, fog, and atmospheric depth.
- Dark, cinematic composition.
- Crisp, angular futuristic interface elements.

Do not redesign the city into an unrelated wallpaper.

### Color palette

| Element | Value |
|---|---|
| Primary violet | `#6E3CBC` |
| Neon accent | `#8C5CF6` |
| Silver | `#C0C0C0` |
| Near-black | `#0F0F0F` |
| Text | Pale lavender / silver |

Active-window borders: violet → silver → near-black, approximately **45°** with **90% opacity**. Use the closest visually faithful syntax supported by the actually installed Hyprland version. Never invent config syntax.

Favor angular surfaces, squared corners, thin borders, precise spacing, subtle glow, elegant monospace typography, and fast responsive motion. Allow minimal 4–6px rounding on application windows. Avoid oversized rounded cards, excessive blur, floating clutter, elastic animation, and gratuitous glassmorphism.

## 2. Living City Wallpaper

Implement a continuously animated city with, where practical:

- GPU-accelerated falling rain at different depths.
- Subtle raindrop distortion.
- Gentle cloud movement.
- Organic neon flickering.
- Shimmering reflections on the water.
- Distant moving vehicles.
- Localized illumination / hover effects.
- Optional restrained parallax.
- Performance-aware rendering and reduced-motion mode.

The city must remain the **same visual scene** during normal desktop use and City Interaction Mode; do not replace it with a separate map, game, or another city image. Environmental animation should continue when switching workspaces, subject to power-saving or compositor limitations.

Investigate Quickshell, Qt/QML, shaders, wallpaper engines and Wayland layer surfaces. Select the renderer based on real compatibility, GPU usage, input handling, and maintainability. Quickshell should handle the shell UI, but it need not be the wallpaper renderer if a dedicated solution is better. Prefer layered animation of existing artwork rather than generating replacement city scenes. Provide configurable quality/FPS profiles and measure resource usage.

## 3. City Interaction Mode

**Primary shortcut: `SUPER + S`.**

Expected experience:

1. From an application workspace, `SUPER + S` reveals the same live city wallpaper.
2. Interactive building regions illuminate subtly; no permanent labels clutter the normal wallpaper.
3. Hover reveals the building's name, assigned workspace/actions, and running status.
4. Clicking a region switches to the mapped workspace, focuses an existing window, launches an application, or performs its configured action.
5. Workspace activation respects its **assigned monitor**, even when the click originated on another monitor.
6. Running windows are preserved; avoid launching duplicates unnecessarily.
7. `SUPER + S` from a working workspace brings the user back to the city; when already in city mode it may toggle back to the previous context.
8. `ESC` while navigating dismisses City Interaction Mode and restores previous workspace/focus.
9. Existing keyboard workspace shortcuts remain available and unchanged unless explicitly approved.

**Architecture caveat:** Hyprland typically keeps a visible workspace per monitor; do not assume a global workspace can be “closed.” Research and implement a reliable city overlay/home workspace technique that preserves the prior monitor-specific focus and state. Define exact behavior for an already active workspace, an empty workspace, and differing monitor scaling.

Technical requirements:
- Hyprland IPC, dispatchers, and event subscriptions as appropriate.
- Monitor-aware focus and workspace rules.
- Input-pass-through outside interaction regions; no invisible overlay intercepting ordinary desktop clicks.
- Per-display geometry/scaling support.
- Graceful compositor reload and error recovery.
- Optional subtle light-pulse feedback from the selected building before transition.

## 4. Customizable City Architecture

Buildings are data-driven interactive entities, not hardcoded launch buttons.

Each supports:
- Stable identifier and label.
- Geometry/hotspot aligned to the master city image.
- Configurable monitor/workspace targeting.
- One or more typed actions (switch/focus/launch/open dashboard).
- Launch command and existing-window detection.
- Running/idle/busy/error state.
- Hover and selected illumination.
- Tooltip and optional status provider.

Choose a maintainable config format (JSON, YAML or QML-backed models). Building positions must scale correctly with wallpaper crop and display aspect ratio. A future configuration UI may edit mappings and regions without changing rendering code. Avoid arbitrary command execution from untrusted settings.

### Initial city destinations

**Nvim — Small Code Correction Building**
- Occasional manual edits when AI assistance is unnecessary.
- A smaller, less visually dominant building in the development area.

**Herdr — Agent Operations Tower**
- The primary agent-monitoring destination.
- Two sessions initially, extensible to more.
- Discover actual application/session interfaces before implementing live status; do not fabricate integration APIs.

**Paperclip — AI Company Headquarters**
- Large-project and future AI-company orchestration.
- Designed to expand as Paperclip becomes central to the workflow.
- Confirm actual commands/API integration before promising live project state.

**Browser District — Twin Towers**
- **Zen Browser:** personal browsing.
- **Google Chrome:** AI-controlled browser workflows.
- Independent targets and existing-window detection.

**Infrastructure District — Background Processes**
- btop, `npm run dev`, log tailing, and a potential future monitoring dashboard.
- Status when reliable: running/stopped/error and relevant process information.

**Lazygit — Git Review & Version Control Building**
- Dedicated building near Nvim within the Development District, separate from Herdr and Paperclip.
- Primary purpose: **human review of Git changes made by Claude Code, Hermes, and other agents** without relying on AI summaries.
- Visual treatment: compact building with subtle Git branch/merge motifs and status-dependent illumination.
- Launch/focus Lazygit in a terminal, ideally after selecting the Git repository.
- Support multiple projects and repositories; **do not hardcode one repository**.
- Display trustworthy status where feasible: current branch, uncommitted changes, staged files.
- Permit inspecting diffs, staging, commits, and history.
- Avoid duplicate terminal sessions where possible.
- Accessible via an independent keyboard shortcut (propose `SUPER + G`, first check for conflicts).
- Remain fully functional when AI tools are unavailable.

#### Lazygit repository selector

Click Lazygit building → choose an actual discovered repository → open Lazygit in that repository's working directory. Populate the selector with discoverable local repositories and/or user-configured favorites (e.g. payroll/HR project, AI workspace, NEON RAIN dotfiles, if present). Do **not** assume illustrative paths exist. A keyboard-first shortcut may open Lazygit for the active project if that project can be determined safely, otherwise show the repository selector.

## 5. Quickshell Dashboard

Build a custom **top dropdown** dashboard, not a fullscreen control center, using modular and responsive Quickshell UI matching the styleframes.

Components, as integrations allow:
- Workspaces and launcher.
- Clock/calendar.
- CPU, RAM and GPU.
- Network activity.
- Audio and music controls.
- Notifications.
- Herdr agent/session status.
- Paperclip status if supported.
- Background-process overview.
- Git/Lazygit shortcut or Git summary.
- Power/session controls.

Prioritize working widgets and accurate state over decoration. Keep components angular, sharp, and coherent with the main desktop.

## 6. Hyprland Styling and Motion

- Exact or closest supported active border gradient: `#6E3CBC` → `#C0C0C0` → `#0F0F0F`, approx. 45°, 90% opacity.
- Restrained inactive border.
- Small consistent gaps.
- Slight window rounding.
- Fast opening, closing, resizing, workspace changes and focus feedback.
- No bouncing, dramatic 3D motion, or excessive blur.
- Preserve useful existing keybindings, and inspect conflicts before adding `SUPER + S`/`SUPER + G`.

## 7. Hyprlock — Neon Rain

Match the supplied lock-screen reference:
- Same city background where possible.
- Dark violet and near-black atmosphere.
- Bright purple `#8C5CF6` accents.
- Pale-lavender typography.
- Clock, date, minimal user identity, sharp rectangular password field.
- Atmospheric rain/glass treatment.

Investigate if true live rain on Hyprlock is supported securely and reliably; if not, provide the closest stable visual alternative. Never compromise authentication security to achieve effects.

## 8. Multi-Monitor Behavior

First inspect actual connectors, resolutions, orientation, scaling, and workspace bindings.

**Horizontal primary monitor**: immersive city, interactive districts, main workspaces, primary dropdown shell.

**Vertical secondary monitor**: matching portrait-friendly companion view or utility dashboard for Herdr, Paperclip, btop/processes, logs, and notifications. Do not stretch a 16:9 image to portrait; consider a coordinated crop or complementary portrait composition. Preserve existing workspace assignments and ensure selecting a building targets the workspace's assigned monitor.

A clicked building does not automatically relocate its workspace to the monitor where the pointer was clicked. Focus follows the target in a predictable, tested way.

## 9. Engineering Standards, Safety, and Human Git Review

- Modular, maintainable QML/scripts/configuration.
- Reuse APIs, event-driven state, and efficient updates over excessive polling.
- Lifecycle/process supervision, logging, and error handling.
- Backups and rollback before modifying dotfiles.
- Safe compositor startup/reload behavior.
- Discover installed executable paths; don't invent them.
- Measure GPU/CPU/RAM usage and responsiveness.
- Do not add unnecessary dependencies.
- Never silently overwrite the user's changes.
- Never expose sensitive data in dashboard logs or screenshots.

### Human oversight of AI-authored changes

- All changes must be inspectable through Lazygit independent of Hermes/Claude Code.
- Hermes and Claude Code must not silently stage or commit unrelated changes.
- Never automatically rewrite Git history.
- Get explicit approval for destructive Git operations, force-pushes, resets, or discarding existing uncommitted work.
- Prefer scoped, reviewable changes and meaningful commit messages.
- Organize generated files so the user can inspect diffs.
- At milestone boundaries, present what changed and give an opportunity for Lazygit review.
- Do not make code review depend on agent summaries.

## 10. Hermes and Claude Code Responsibilities

**Hermes:** project orchestrator, planner, reviewer, coordinator, verifier, and keeper of long-term project state.

**Claude Code:** scoped implementation executor for QML/Quickshell, Hyprland configuration, shaders, scripts, tests, debugging, refactoring, and docs.

Hermes must verify delegated outcomes rather than treating agent-completed tasks as automatically correct. Avoid parallel agents editing the same files without coordination.

## 11. Execution Milestones

### M0 — Environment Audit and Architecture

Inspect OS, Hyprland/Quickshell/Hyprlock versions, GPU stack, monitors, workspaces, current dotfiles, shortcuts, wallpaper mechanisms, existing app commands, and actual repository locations. Deliver architecture, dependencies, risks, acceptance tests, and rollback design. **Do not modify the machine yet.**

### M1 — Living Wallpaper Prototype

Render the approved city artwork with live rain. Benchmark performance, scaling, and appearance. Avoid rebuilding the city from scratch.

### M2 — First Interactive Building

Implement `SUPER + S`, a clickable Herdr tower, accurate monitor-aware workspace activation, return behavior, and click pass-through. Verify actual focus behavior.

### M3 — Configurable Building System

Add Nvim, Herdr, Paperclip, Zen, Chrome, Infrastructure, and Lazygit. Implement data-driven hotspots, repository selector, app/window matching, and state indicators.

### M4 — Quickshell Dropdown

Implement top bar, dropdown dashboard, functional widgets, and reusable theme components.

### M5 — Styling and Animations

Apply Hyprland borders, focus transitions, gaps, and motion polish; test existing keybindings and workflow compatibility.

### M6 — Hyprlock and Portrait Monitor

Implement Neon Rain lock screen and complementary vertical display layout.

### M7 — Integration and Reliability

Test monitor focus, workspace persistence, application launch/reuse, repo selection, status refresh, compositor reload, graceful failures, resource usage, and rollback. Fix regressions and document installation.

## 12. Completion Criteria

The goal is complete only when:

- The approved city artwork remains recognizable and faithfully rendered.
- Live rain works reliably without unreasonable system load.
- `SUPER + S` reveals and dismisses the same live city as designed.
- Clickable buildings activate the correct targets.
- Assigned workspace monitors are respected.
- Normal keyboard-driven Hyprland use stays intact.
- Running apps are not unnecessarily terminated/recreated.
- Buildings and mappings can be configured independently of renderer code.
- Quickshell top dropdown works.
- Hyprland theme and animations match the sharp cyberpunk direction.
- Hyprlock matches Neon Rain as closely as securely supported.
- Vertical display has a practical cohesive layout.
- Lazygit can open from its building and an independent shortcut.
- Lazygit supports selecting among multiple actual repositories.
- User can manually inspect agent-created diffs and Git state without AI.
- Reload/startup, failure recovery, security, and performance have been tested.
- Setup, customization, and rollback documentation exists.

Report unsupported details honestly instead of marking them completed.

## 13. Working Rules

Start with inspection. Back up dotfiles before edits. Work incrementally, test each milestone, and preserve current configuration and uncommitted Git changes. Ask approval before package installation, system-risk changes, destructive commands, or changes that could make the desktop inaccessible. Continue approved, ordinary scoped implementation autonomously. Keep the selected styleframes as reference throughout.

Maintain project-state documents:

```text
neon-rain/
├── GOAL.md
├── STATE.md
├── ARCHITECTURE.md
├── TASKS.md
├── DECISIONS.md
├── assets/
│   ├── city-reference.png
│   └── hyprlock-reference.png
├── config/
├── quickshell/
├── wallpaper/
├── scripts/
└── tests/
```

`STATE.md` must describe completed milestones, pending work, architectural decisions, blockers, and the next concrete action, so Hermes can resume across sessions.

**Begin with M0. Inspect and deliver the architecture and proposed first prototype before making changes.**

The ultimate objective is a genuinely usable, visually exceptional, customizable Linux desktop where an interactive living cyberpunk city becomes the central navigation experience and Git changes remain directly reviewable by the user.
