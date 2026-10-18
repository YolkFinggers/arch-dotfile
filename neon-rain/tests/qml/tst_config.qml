import QtQuick
import QtTest
import "../../wallpaper/lib/profiles.js" as Profiles

// The shipped config/wallpaper.json must parse and resolve with zero warnings.
// Needs QML_XHR_ALLOW_FILE_READ=1 (set by tests/run-unit.sh).
TestCase {
    name: "ShippedConfig"

    function readJson(relPath) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl(relPath), false);
        xhr.send();
        verify(xhr.responseText.length > 0, `cannot read ${relPath}`);
        return JSON.parse(xhr.responseText);
    }

    function test_wallpaperJsonResolvesClean() {
        const cfg = readJson("../../config/wallpaper.json");
        const s = Profiles.resolve(cfg, {}, {});
        compare(s.warnings.length, 0, JSON.stringify(s.warnings));
        verify(s.fps >= 1 && s.fps <= 120);
        for (const name of Object.keys(cfg.outputs || {})) {
            const f = Profiles.outputFocus(cfg, name);
            verify(f.focusX >= 0 && f.focusX <= 1 && f.focusY >= 0 && f.focusY <= 1, name);
        }
    }
}
