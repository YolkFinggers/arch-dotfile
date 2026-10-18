import QtQuick
import QtTest
import "../../wallpaper/lib/geometry.js" as Geometry

// Unit tests for the cover-crop maths in wallpaper/lib/geometry.js.
// Run: tests/run-unit.sh (qmltestrunner, offscreen; no compositor needed).
TestCase {
    name: "Geometry"

    // Master artwork size (assets/city-raw.png).
    readonly property int imgW: 1672
    readonly property int imgH: 941

    function fuzzy(actual, expected, eps, msg) {
        verify(Math.abs(actual - expected) <= eps, `${msg}: ${actual} != ${expected} (eps ${eps})`);
    }

    // The scaled artwork must cover the view on both axes and fit exactly on one.
    function checkCover(c, viewW, viewH) {
        verify(c !== null, "crop is null");
        verify(imgW * c.scale >= viewW - 1e-6, "does not cover width");
        verify(imgH * c.scale >= viewH - 1e-6, "does not cover height");
        verify(Math.abs(imgW * c.scale - viewW) < 1e-6 || Math.abs(imgH * c.scale - viewH) < 1e-6, "neither axis fits exactly");
        // Uniform scale: visible source rect has the view's aspect ratio (no stretching).
        fuzzy(c.srcW / c.srcH, viewW / viewH, 1e-9, "aspect");
        fuzzy(c.srcW * c.scale, viewW, 1e-6, "srcW*scale");
        fuzzy(c.srcH * c.scale, viewH, 1e-6, "srcH*scale");
        verify(c.srcX >= 0 && c.srcX + c.srcW <= imgW + 1e-6, "crop x outside artwork");
        verify(c.srcY >= 0 && c.srcY + c.srcH <= imgH + 1e-6, "crop y outside artwork");
    }

    function test_actualOutputs_data() {
        // Logical sizes of the real outputs (hyprctl monitors: scale 1, HDMI-A-1 transform 1),
        // plus a few synthetic shapes that are not attached today.
        return [
            { tag: "eDP-1 1920x1080", w: 1920, h: 1080 },
            { tag: "DP-1 1920x1080", w: 1920, h: 1080 },
            { tag: "HDMI-A-1 portrait 1080x1920", w: 1080, h: 1920 },
            { tag: "synthetic ultrawide 3440x1440", w: 3440, h: 1440 },
            { tag: "synthetic scale 1.5 2560x1600", w: 2560 / 1.5, h: 1600 / 1.5 },
            { tag: "exact artwork size", w: 1672, h: 941 }
        ];
    }

    function test_actualOutputs(data) {
        checkCover(Geometry.coverCrop(imgW, imgH, data.w, data.h, 0.5, 0.5), data.w, data.h);
    }

    function test_landscape1080p() {
        const c = Geometry.coverCrop(imgW, imgH, 1920, 1080, 0.5, 0.5);
        fuzzy(c.scale, 1920 / 1672, 1e-12, "scale");
        compare(c.uvScaleX, 1);
        fuzzy(c.srcX, 0, 1e-9, "srcX");
        // 941 * 1.1483 = 1080.6 px tall: ~0.5 artwork px cropped, split evenly.
        fuzzy(c.srcH, 1080 / c.scale, 1e-9, "srcH");
        fuzzy(c.srcY, (imgH - c.srcH) / 2, 1e-9, "srcY centred");
    }

    function test_portraitCropsWidthNotStretch() {
        const c = Geometry.coverCrop(imgW, imgH, 1080, 1920, 0.5, 0.5);
        fuzzy(c.scale, 1920 / 941, 1e-12, "scale fits height");
        compare(c.uvScaleY, 1);
        fuzzy(c.srcW, 1080 / c.scale, 1e-9, "srcW");
        fuzzy(c.srcX, (imgW - c.srcW) / 2, 1e-9, "centred");
        // Live IPC status reported srcX 571.3 srcW 529.3 for HDMI-A-1.
        fuzzy(c.srcX, 571.3, 0.05, "matches live status srcX");
        fuzzy(c.srcW, 529.3, 0.05, "matches live status srcW");
    }

    function test_focusExtremes() {
        const left = Geometry.coverCrop(imgW, imgH, 1080, 1920, 0, 0.5);
        const right = Geometry.coverCrop(imgW, imgH, 1080, 1920, 1, 0.5);
        fuzzy(left.srcX, 0, 1e-9, "focusX 0 keeps left edge");
        fuzzy(right.srcX + right.srcW, imgW, 1e-9, "focusX 1 keeps right edge");
    }

    function test_focusClampedAndDefaulted() {
        const a = Geometry.coverCrop(imgW, imgH, 1080, 1920, -3, 9);
        const b = Geometry.coverCrop(imgW, imgH, 1080, 1920, 0, 1);
        compare(a.srcX, b.srcX);
        const n = Geometry.coverCrop(imgW, imgH, 1080, 1920, NaN, "x");
        const c = Geometry.coverCrop(imgW, imgH, 1080, 1920, 0.5, 0.5);
        compare(n.srcX, c.srcX);
        compare(n.srcY, c.srcY);
    }

    function test_invalidInputsReturnNull_data() {
        return [
            { tag: "zero image", a: [0, 941, 1920, 1080] },
            { tag: "zero view (artwork not loaded yet)", a: [1672, 941, 0, 0] },
            { tag: "negative", a: [1672, -1, 1920, 1080] },
            { tag: "NaN", a: [NaN, 941, 1920, 1080] },
            { tag: "infinite", a: [Infinity, 941, 1920, 1080] },
            { tag: "string", a: ["1672", 941, 1920, 1080] }
        ];
    }

    function test_invalidInputsReturnNull(data) {
        compare(Geometry.coverCrop(data.a[0], data.a[1], data.a[2], data.a[3], 0.5, 0.5), null);
    }

    function test_roundTripImageView() {
        const c = Geometry.coverCrop(imgW, imgH, 1080, 1920, 0.3, 0.5);
        const pts = [[0, 0], [c.srcX, 0], [800, 470], [imgW, imgH]];
        for (const p of pts) {
            const v = Geometry.imageToView(c, p[0], p[1]);
            const back = Geometry.viewToImage(c, v.x, v.y);
            fuzzy(back.x, p[0], 1e-9, "round trip x");
            fuzzy(back.y, p[1], 1e-9, "round trip y");
        }
        const tl = Geometry.imageToView(c, c.srcX, c.srcY);
        fuzzy(tl.x, 0, 1e-9, "crop origin maps to view 0");
        const br = Geometry.imageToView(c, c.srcX + c.srcW, c.srcY + c.srcH);
        fuzzy(br.x, 1080, 1e-6, "crop end maps to view width");
        fuzzy(br.y, 1920, 1e-6, "crop end maps to view height");
    }
}
