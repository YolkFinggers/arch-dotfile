import QtQuick
import QtTest
import "../../wallpaper/lib/profiles.js" as Profiles

// Unit tests for settings resolution in wallpaper/lib/profiles.js.
// Run: tests/run-unit.sh (qmltestrunner, offscreen; no compositor needed).
TestCase {
    name: "Profiles"

    function fuzzy(actual, expected, eps) {
        verify(Math.abs(actual - expected) <= eps, `${actual} != ${expected}`);
    }

    function test_defaultsWithNothingSet() {
        const s = Profiles.resolve(null, {}, {});
        compare(s.profile, "balanced");
        compare(s.fps, 30);
        compare(s.frameIntervalMs, 33);
        compare(s.layers, 3);
        compare(s.animate, true);
        compare(s.reducedMotion, false);
        compare(s.intensity, 1.0);
        compare(s.speed, 1.0);
        compare(s.warnings.length, 0);
    }

    function test_profileTable_data() {
        return [
            { tag: "eco", fps: 15, layers: 2, distortion: 0.0 },
            { tag: "balanced", fps: 30, layers: 3, distortion: 0.5 },
            { tag: "smooth", fps: 60, layers: 4, distortion: 1.0 }
        ];
    }

    function test_profileTable(data) {
        const s = Profiles.resolve({ profile: data.tag }, {}, {});
        compare(s.profile, data.tag);
        compare(s.fps, data.fps);
        compare(s.layers, data.layers);
        compare(s.distortion, data.distortion);
        compare(s.frameIntervalMs, Math.round(1000 / data.fps));
    }

    function test_precedenceOverrideEnvConfig() {
        const cfg = { profile: "eco", fps: 20 };
        const env = { NEON_RAIN_PROFILE: "smooth", NEON_RAIN_FPS: "45" };
        let s = Profiles.resolve(cfg, {}, {});
        compare(s.profile, "eco");
        compare(s.fps, 20);
        s = Profiles.resolve(cfg, env, {});
        compare(s.profile, "smooth");
        compare(s.fps, 45);
        s = Profiles.resolve(cfg, env, { profile: "balanced", fps: 24 });
        compare(s.profile, "balanced");
        compare(s.fps, 24);
        // null / empty string mean "not set" and fall through.
        s = Profiles.resolve(cfg, { NEON_RAIN_PROFILE: "" }, { profile: null });
        compare(s.profile, "eco");
    }

    function test_unknownProfileWarns() {
        const s = Profiles.resolve({ profile: "ultra" }, {}, {});
        compare(s.profile, "balanced");
        compare(s.warnings.length, 1);
        verify(s.warnings[0].indexOf("ultra") !== -1);
    }

    function test_prototypeKeysNotAcceptedAsProfiles() {
        // Object.prototype keys must not be treated as profile names.
        const s = Profiles.resolve({ profile: "toString" }, {}, {});
        compare(s.profile, "balanced");
        compare(s.warnings.length, 1);
    }

    function test_fpsValidation_data() {
        return [
            { tag: "string int", v: "24", fps: 24, warn: 0 },
            { tag: "clamp high", v: 500, fps: 120, warn: 1 },
            { tag: "clamp low", v: 0, fps: 1, warn: 1 },
            { tag: "fractional", v: 29.97, fps: 30, warn: 1 },
            { tag: "garbage", v: "fast", fps: 30, warn: 1 },
            { tag: "null ignored", v: null, fps: 30, warn: 0 }
        ];
    }

    function test_fpsValidation(data) {
        const s = Profiles.resolve({ fps: data.v }, {}, {});
        compare(s.fps, data.fps);
        compare(s.warnings.length, data.warn);
        compare(s.frameIntervalMs, Math.round(1000 / data.fps));
    }

    function test_reducedMotionStatic() {
        const s = Profiles.resolve({ profile: "smooth", reducedMotion: true, fps: 90 }, {}, {});
        compare(s.reducedMotion, true);
        compare(s.reducedMotionStyle, "static");
        compare(s.animate, false);
        compare(s.fps, 0);
        compare(s.frameIntervalMs, 0);
        compare(s.layers, 2);
        compare(s.distortion, 0.0);
    }

    function test_reducedMotionSlow() {
        const s = Profiles.resolve({ profile: "smooth", reducedMotion: true, reducedMotionStyle: "slow", rain: { speed: 2 } }, {}, {});
        compare(s.animate, true);
        compare(s.fps, 10);
        compare(s.layers, 1);
        compare(s.distortion, 0.0);
        fuzzy(s.speed, 2 * 0.35, 1e-12);
    }

    function test_reducedMotionBeatsFpsOverride() {
        const s = Profiles.resolve({ reducedMotion: true, reducedMotionStyle: "slow" }, {}, { fps: 60 });
        compare(s.fps, 10);
    }

    function test_reducedMotionParsing_data() {
        return [
            { tag: "env '1'", env: "1", want: true, warn: 0 },
            { tag: "env 'off'", env: "off", want: false, warn: 0 },
            { tag: "env ' YES '", env: " YES ", want: true, warn: 0 },
            { tag: "env 'maybe'", env: "maybe", want: false, warn: 1 }
        ];
    }

    function test_reducedMotionParsing(data) {
        const s = Profiles.resolve({}, { NEON_RAIN_REDUCED_MOTION: data.env }, {});
        compare(s.reducedMotion, data.want);
        compare(s.warnings.length, data.warn);
    }

    function test_ipcOverrideFalseBeatsConfigTrue() {
        const s = Profiles.resolve({ reducedMotion: true }, {}, { reducedMotion: false });
        compare(s.reducedMotion, false);
        compare(s.animate, true);
    }

    function test_invalidReducedStyle() {
        const s = Profiles.resolve({ reducedMotionStyle: "wobbly" }, {}, {});
        compare(s.reducedMotionStyle, "static");
        compare(s.warnings.length, 1);
    }

    function test_rainClamps() {
        let s = Profiles.resolve({ rain: { intensity: 9, speed: 0 } }, {}, {});
        compare(s.intensity, 2);
        fuzzy(s.speed, 0.1, 1e-12);
        s = Profiles.resolve({ rain: { intensity: "x", speed: NaN } }, {}, {});
        compare(s.intensity, 1.0);
        compare(s.speed, 1.0);
        s = Profiles.resolve({ rain: "nope" }, {}, {});
        compare(s.intensity, 1.0);
    }

    function test_outputFocus() {
        const cfg = { outputs: { "default": { focusX: 0.2 }, "HDMI-A-1": { focusX: 2, focusY: -1 } } };
        let f = Profiles.outputFocus(cfg, "HDMI-A-1");
        compare(f.focusX, 1);
        compare(f.focusY, 0);
        f = Profiles.outputFocus(cfg, "eDP-1");
        compare(f.focusX, 0.2);
        compare(f.focusY, 0.5);
        f = Profiles.outputFocus(null, "eDP-1");
        compare(f.focusX, 0.5);
    }
}
