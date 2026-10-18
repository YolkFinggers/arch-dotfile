import QtQuick
import QtTest
import "../../wallpaper/lib/diagnostics.js" as Diagnostics

// The status-name mapping must follow Qt's real ShaderEffect.Status enum, and the report
// must only flag a failure on Error (Uncompiled is reported live while rain draws).
TestCase {
    name: "ShaderDiagnostics"

    function test_enumMatchesQt() {
        compare(Diagnostics.COMPILED, ShaderEffect.Compiled);
        compare(Diagnostics.UNCOMPILED, ShaderEffect.Uncompiled);
        compare(Diagnostics.ERROR, ShaderEffect.Error);
        compare(Diagnostics.shaderStatusName(ShaderEffect.Compiled), "Compiled");
        compare(Diagnostics.shaderStatusName(ShaderEffect.Uncompiled), "Uncompiled");
        compare(Diagnostics.shaderStatusName(ShaderEffect.Error), "Error");
        compare(Diagnostics.shaderStatusName(7), "Unknown(7)");
    }

    function test_uncompiledIsNotAnError() {
        const r = Diagnostics.shaderReport(ShaderEffect.Uncompiled, "", false);
        compare(r.qtStatus, "Uncompiled");
        compare(r.health, "no-error");
        compare(r.compiledSeen, false);
        verify(r.note.indexOf("verify-rain.sh") >= 0);
    }

    function test_errorIsReportedWithLog() {
        const r = Diagnostics.shaderReport(ShaderEffect.Error, "bad qsb", true);
        compare(r.health, "error");
        compare(r.log, "bad qsb");
        compare(r.compiledSeen, true);
    }
}
