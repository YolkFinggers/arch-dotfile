.pragma library

// Quality profiles and settings resolution for the rain wallpaper.
//
// Precedence (highest first): runtime IPC override > environment > config file > defaults.
// Every resolved value is validated; anything invalid falls back and is reported in
// `warnings` so the caller can log it instead of silently misbehaving.

const PROFILES = {
    // fps: timer cadence. layers: rain depth layers drawn by the shader (1..4).
    // density: fraction of rain columns that carry drops. distortion: refraction strength.
    eco: { fps: 15, layers: 2, density: 0.45, distortion: 0.0 },
    balanced: { fps: 30, layers: 3, density: 0.6, distortion: 0.5 },
    smooth: { fps: 60, layers: 4, density: 0.7, distortion: 1.0 }
};

const DEFAULT_PROFILE = "balanced";
const MIN_FPS = 1;
const MAX_FPS = 120;
const REDUCED_STYLES = ["static", "slow"];

// "Slow" reduced motion: one sparse layer, no refraction, a third of the speed, 10 fps.
const SLOW_REDUCED = { fps: 10, layers: 1, density: 0.35, distortion: 0.0, speedFactor: 0.35 };

function parseBool(v) {
    if (typeof v === "boolean")
        return v;
    if (typeof v === "number")
        return v !== 0;
    if (typeof v === "string") {
        const s = v.trim().toLowerCase();
        if (["1", "true", "yes", "on"].indexOf(s) !== -1)
            return true;
        if (["0", "false", "no", "off"].indexOf(s) !== -1)
            return false;
    }
    return null;
}

// null = not set, NaN = invalid, otherwise an integer.
function parseFps(v) {
    if (v === null || v === undefined || v === "")
        return null;
    const n = typeof v === "number" ? v : Number(String(v).trim());
    if (!isFinite(n) || Math.floor(n) !== n)
        return NaN;
    return n;
}

function clampNumber(v, lo, hi, fallback) {
    if (typeof v !== "number" || !isFinite(v))
        return fallback;
    return Math.min(hi, Math.max(lo, v));
}

function profileNames() {
    return Object.keys(PROFILES);
}

function firstSet(values) {
    for (let i = 0; i < values.length; i++) {
        if (values[i] !== null && values[i] !== undefined && values[i] !== "")
            return values[i];
    }
    return undefined;
}

// config: parsed wallpaper.json (may be null). env: { NEON_RAIN_PROFILE, NEON_RAIN_FPS,
// NEON_RAIN_REDUCED_MOTION } with string-or-undefined values. overrides: runtime IPC values
// { profile, fps, reducedMotion } where null/undefined means "not overridden".
function resolve(config, env, overrides) {
    const cfg = config && typeof config === "object" ? config : {};
    const e = env || {};
    const o = overrides || {};
    const warnings = [];

    let profile = firstSet([o.profile, e.NEON_RAIN_PROFILE, cfg.profile]);
    if (profile === undefined) {
        profile = DEFAULT_PROFILE;
    } else if (!Object.prototype.hasOwnProperty.call(PROFILES, profile)) {
        warnings.push("unknown profile '" + profile + "', using '" + DEFAULT_PROFILE + "'");
        profile = DEFAULT_PROFILE;
    }

    let reducedMotion = false;
    const rmRaw = firstSet([o.reducedMotion, e.NEON_RAIN_REDUCED_MOTION, cfg.reducedMotion]);
    if (rmRaw !== undefined) {
        const b = parseBool(rmRaw);
        if (b === null)
            warnings.push("invalid reducedMotion '" + rmRaw + "', using false");
        else
            reducedMotion = b;
    }

    let reducedStyle = cfg.reducedMotionStyle === undefined ? "static" : cfg.reducedMotionStyle;
    if (REDUCED_STYLES.indexOf(reducedStyle) === -1) {
        warnings.push("invalid reducedMotionStyle '" + reducedStyle + "', using 'static'");
        reducedStyle = "static";
    }

    const base = PROFILES[profile];
    let fps = base.fps;
    let layers = base.layers;
    let density = base.density;
    let distortion = base.distortion;
    let speedFactor = 1.0;
    let animate = true;

    if (reducedMotion) {
        if (reducedStyle === "static") {
            // One rendered frame and no timer: rain stays visible but nothing moves.
            animate = false;
            fps = 0;
            layers = Math.min(layers, 2);
            distortion = 0.0;
        } else {
            fps = SLOW_REDUCED.fps;
            layers = SLOW_REDUCED.layers;
            density = SLOW_REDUCED.density;
            distortion = SLOW_REDUCED.distortion;
            speedFactor = SLOW_REDUCED.speedFactor;
        }
    }

    // An explicit fps override applies only at full motion; reduced motion always wins.
    const fpsRaw = firstSet([o.fps, e.NEON_RAIN_FPS, cfg.fps]);
    if (fpsRaw !== undefined && !reducedMotion) {
        const n = parseFps(fpsRaw);
        if (isNaN(n)) {
            warnings.push("invalid fps '" + fpsRaw + "', using profile fps " + fps);
        } else if (n < MIN_FPS || n > MAX_FPS) {
            const c = Math.min(MAX_FPS, Math.max(MIN_FPS, n));
            warnings.push("fps " + n + " out of range " + MIN_FPS + ".." + MAX_FPS + ", clamped to " + c);
            fps = c;
        } else {
            fps = n;
        }
    }

    const rain = cfg.rain && typeof cfg.rain === "object" ? cfg.rain : {};
    const intensity = clampNumber(rain.intensity, 0, 2, 1.0);
    const speed = clampNumber(rain.speed, 0.1, 3, 1.0) * speedFactor;

    return {
        profile: profile,
        reducedMotion: reducedMotion,
        reducedMotionStyle: reducedStyle,
        animate: animate,
        fps: fps,
        frameIntervalMs: animate ? Math.round(1000 / fps) : 0,
        layers: layers,
        density: density,
        distortion: distortion,
        intensity: intensity,
        speed: speed,
        warnings: warnings
    };
}

// Per-output crop focus, falling back to the "default" entry, then centre.
function outputFocus(config, outputName) {
    const outputs = config && config.outputs && typeof config.outputs === "object" ? config.outputs : {};
    const entry = outputs[outputName] || outputs["default"] || {};
    return {
        focusX: clampNumber(entry.focusX, 0, 1, 0.5),
        focusY: clampNumber(entry.focusY, 0, 1, 0.5)
    };
}
