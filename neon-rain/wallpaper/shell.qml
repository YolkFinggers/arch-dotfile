import QtQuick
import Quickshell
import Quickshell.Io
import "lib/profiles.js" as Profiles

// NEON RAIN M1 living wallpaper. Runs as its own Quickshell instance
// (`quickshell --path <repo>/neon-rain/wallpaper`), separate from the bar in
// ~/.config/quickshell, so starting/stopping it never touches the bar.
//
// One shared Timer advances `time` at the profile's explicit cadence; every output's
// ShaderEffect reads it, so all screens animate in lockstep and only re-render on ticks.
ShellRoot {
    id: root

    // neon-rain/ (parent of this shell dir). Quickshell blackholes relative "../" URLs that
    // leave the shell dir, so assets and config are addressed by absolute path instead.
    readonly property string projectDir: {
        const dir = Quickshell.shellDir.replace(/\/+$/, "");
        return dir.substring(0, dir.lastIndexOf("/"));
    }
    property var config: null
    // Runtime overrides from IPC; null means "use env/config".
    property var overrides: ({ profile: null, fps: null, reducedMotion: null })
    readonly property var settings: Profiles.resolve(config, {
        NEON_RAIN_PROFILE: Quickshell.env("NEON_RAIN_PROFILE"),
        NEON_RAIN_FPS: Quickshell.env("NEON_RAIN_FPS"),
        NEON_RAIN_REDUCED_MOTION: Quickshell.env("NEON_RAIN_REDUCED_MOTION")
    }, overrides)

    // Wrapped so float32 precision in the shader never degrades (time * px/s stays small).
    readonly property real timeWrapSeconds: 600
    property real time: 0
    property double startMs: Date.now()
    property int ticks: 0
    property double ticksSinceMs: Date.now()

    function parseConfig(text) {
        try {
            root.config = JSON.parse(text);
        } catch (e) {
            console.warn(`neon-rain: config parse error, keeping previous config: ${e}`);
        }
    }

    onSettingsChanged: {
        ticks = 0;
        ticksSinceMs = Date.now();
        console.info(`neon-rain: settings profile=${settings.profile} fps=${settings.fps} interval=${settings.frameIntervalMs}ms layers=${settings.layers} reducedMotion=${settings.reducedMotion}(${settings.reducedMotionStyle}) animate=${settings.animate}`);
        for (const w of settings.warnings)
            console.warn(`neon-rain: ${w}`);
    }

    FileView {
        id: configFile

        path: root.projectDir + "/config/wallpaper.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseConfig(text())
        onLoadFailed: error => console.warn(`neon-rain: cannot read ${path} (${FileViewError.toString(error)}), using defaults`)
    }

    Timer {
        interval: root.settings.animate ? root.settings.frameIntervalMs : 1000
        running: root.settings.animate
        repeat: true
        onTriggered: {
            root.time = ((Date.now() - root.startMs) / 1000) % root.timeWrapSeconds;
            root.ticks++;
        }
    }

    Variants {
        id: surfaces

        model: Quickshell.screens

        RainWallpaper {
            artworkPath: root.projectDir + "/assets/city-raw.png"
            settings: root.settings
            config: root.config
            time: root.time
        }
    }

    // --- City Mode (M2) ---------------------------------------------------------------------
    // Opened/closed by scripts/city-ctl (SUPER+U) through IPC. Showing the city never switches
    // workspaces; the focused window and monitor at open time are restored on ESC/toggle.
    property var city: null
    property bool cityOpen: false
    property string cityOutput: ""
    property string cityPrevWindow: "-"
    property var cityStatus: null
    property var cityLast: null
    readonly property string cityCtl: root.projectDir + "/scripts/city-ctl"

    FileView {
        path: root.projectDir + "/config/city.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.city = JSON.parse(text());
            } catch (e) {
                console.warn(`neon-rain: city.json parse error, keeping previous: ${e}`);
            }
        }
    }

    function cityRun(args, onResult) {
        const p = cityProc.createObject(root, { command: [root.cityCtl].concat(args) });
        p.done.connect(text => {
            let result;
            try {
                result = JSON.parse(text.trim().split("\n").pop());
            } catch (e) {
                result = { error: `bad city-ctl output: ${text.substring(0, 120)}` };
            }
            if (result.error)
                console.warn(`neon-rain: city-ctl ${args[0]}: ${result.error}`);
            onResult(result);
            p.destroy();
        });
        p.running = true;
    }

    function openCity(output, prevWindow) {
        cityOutput = output;
        cityPrevWindow = prevWindow;
        cityStatus = null;
        cityOpen = true;
        console.info(`neon-rain: city open output=${output}`);
        cityRun(["status"], r => root.cityStatus = r);
    }

    // restore=false when a building action takes over focus.
    function closeCity(restore) {
        if (!cityOpen)
            return;
        cityOpen = false;
        console.info(`neon-rain: city close restore=${restore}`);
        if (restore)
            cityRun(["restore", cityPrevWindow, cityOutput || "-"], r => root.cityLast = r);
    }

    function activateBuilding(id) {
        closeCity(false);
        cityRun(["activate", id], r => {
            root.cityLast = r;
            console.info(`neon-rain: city activate ${id}: ${r.action || "error"} verified=${r.verified}`);
        });
    }

    function cityState() {
        return {
            open: cityOpen,
            output: cityOutput,
            prevWindow: cityPrevWindow,
            status: cityStatus,
            last: cityLast,
            overlays: cityOverlays.instances.map(w => w.describe())
        };
    }

    Component {
        id: cityProc

        Process {
            id: proc

            signal done(string text)

            stdout: StdioCollector {
                onStreamFinished: proc.done(text)
            }
        }
    }

    Variants {
        id: cityOverlays

        model: Quickshell.screens

        CityOverlay {
            artworkPath: root.projectDir + "/assets/city-raw.png"
            settings: root.settings
            config: root.config
            city: root.city
            time: root.time
            open: root.cityOpen
            keyboardOutput: root.cityOutput
            status: root.cityStatus
            onActivate: id => root.activateBuilding(id)
            onDismiss: root.closeCity(true)
        }
    }

    // `quickshell ipc --pid <pid> call neonrain <fn>` (wrapped by scripts/neon-rain-proto).
    IpcHandler {
        target: "neonrain"

        function status(): string {
            const elapsed = (Date.now() - root.ticksSinceMs) / 1000;
            return JSON.stringify({
                settings: root.settings,
                overrides: root.overrides,
                uptimeSeconds: Math.round((Date.now() - root.startMs) / 1000),
                ticks: root.ticks,
                measuredTickHz: elapsed > 0 ? +(root.ticks / elapsed).toFixed(2) : 0,
                surfaces: surfaces.instances.map(w => w.describe())
            });
        }
        function setProfile(name: string): string {
            root.overrides = Object.assign({}, root.overrides, { profile: name });
            return JSON.stringify(root.settings);
        }
        function setFps(fps: int): string {
            root.overrides = Object.assign({}, root.overrides, { fps: fps });
            return JSON.stringify(root.settings);
        }
        function setReducedMotion(on: bool): string {
            root.overrides = Object.assign({}, root.overrides, { reducedMotion: on });
            return JSON.stringify(root.settings);
        }
        // Writes <project>/tests/results/live/<tag>-<output>.png per surface (asynchronously).
        // The directory is fixed and the tag is sanitised, so IPC cannot write elsewhere.
        function capture(tag: string): string {
            const safe = String(tag).replace(/[^A-Za-z0-9_-]/g, "").substring(0, 40) || "capture";
            const files = [];
            for (const w of surfaces.instances) {
                const file = `${root.projectDir}/tests/results/live/${safe}-${w.modelData.name}.png`;
                if (w.capture(file))
                    files.push(file);
            }
            return JSON.stringify({ time: root.time, files: files });
        }
        // City Mode. SUPER+U: open with the caller's focused monitor/window, or close and restore.
        function cityToggle(output: string, prevWindow: string): string {
            if (root.cityOpen)
                root.closeCity(true);
            else
                root.openCity(output, prevWindow);
            return JSON.stringify(root.cityState());
        }
        // Same paths as ESC and a hotspot click.
        function cityDismiss(): string {
            root.closeCity(true);
            return JSON.stringify(root.cityState());
        }
        function cityActivate(id: string): string {
            root.activateBuilding(id);
            return JSON.stringify(root.cityState());
        }
        function cityState(): string {
            return JSON.stringify(root.cityState());
        }
        // Overlay item trees only (city + hotspots), never windows, to tests/results/live/.
        function cityCapture(tag: string): string {
            const safe = String(tag).replace(/[^A-Za-z0-9_-]/g, "").substring(0, 40) || "city";
            const files = [];
            for (const w of cityOverlays.instances) {
                if (!w.visible)
                    continue;
                const file = `${root.projectDir}/tests/results/live/${safe}-${w.modelData.name}.png`;
                if (w.capture(file))
                    files.push(file);
            }
            return JSON.stringify({ files: files });
        }
        function clearOverrides(): string {
            root.overrides = { profile: null, fps: null, reducedMotion: null };
            return JSON.stringify(root.settings);
        }
    }
}
