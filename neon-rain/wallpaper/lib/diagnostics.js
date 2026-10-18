.pragma library

// Shader diagnostics for the IPC `status` report.
//
// ShaderEffect.status is NOT a "the shader is drawing" signal. Its enum order is
// Compiled = 0, Uncompiled = 1, Error = 2 (qquickshadereffect_p.h, Qt 6.12). In the live
// prototype every surface reports Uncompiled while two wallpaper-only captures taken
// seconds apart differ by animated rain streaks and match the cover crop, which only the
// custom rain.frag.qsb can produce (see STATE.md). The first launch logged Compiled for one
// surface, which later read Uncompiled again, so the value can fall back without a failure.
// Only Error is a real failure (Qt then also fills ShaderEffect.log). Rendering is proved
// by scripts/verify-rain.sh, not by this value.

// Qt's numeric values, mirrored so the mapping is unit-testable against ShaderEffect.*.
var COMPILED = 0;
var UNCOMPILED = 1;
var ERROR = 2;

function shaderStatusName(status) {
    switch (status) {
    case COMPILED:
        return "Compiled";
    case UNCOMPILED:
        return "Uncompiled";
    case ERROR:
        return "Error";
    default:
        return `Unknown(${status})`;
    }
}

// Summarises one surface's shader state without overclaiming.
//   status:        current ShaderEffect.status
//   log:           current ShaderEffect.log
//   compiledSeen:  true if status was ever Compiled for this surface
// health is "error" only on Error; otherwise "no-error", because Compiled/Uncompiled say
// nothing reliable about whether rain is on screen.
function shaderReport(status, log, compiledSeen) {
    const isError = status === ERROR;
    return {
        qtStatus: shaderStatusName(status),
        health: isError ? "error" : "no-error",
        compiledSeen: !!compiledSeen,
        log: log ? String(log) : "",
        note: isError ? "shader failed; see log" : "qtStatus is not proof of drawing; verify with scripts/verify-rain.sh"
    };
}
