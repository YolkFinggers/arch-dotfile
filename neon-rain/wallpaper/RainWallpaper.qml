import QtQuick
import Quickshell
import Quickshell.Wayland
import "lib/diagnostics.js" as Diagnostics
import "lib/geometry.js" as Geometry
import "lib/profiles.js" as Profiles

// One living-wallpaper surface per output: the approved raw city artwork, cover-cropped
// (never stretched), with GPU rain from shaders/rain.frag on top.
//
// Layer: Bottom, i.e. above hyprpaper (Background) and below every window and the bar.
// Input: empty region, so pointer events fall through. Keyboard: never focusable.
PanelWindow {
    id: win

    required property ShellScreen modelData
    required property string artworkPath
    property var settings
    property var config
    property real time

    readonly property var cropFocus: Profiles.outputFocus(config, modelData.name)
    readonly property var crop: Geometry.coverCrop(art.implicitWidth, art.implicitHeight, width, height, cropFocus.focusX, cropFocus.focusY)

    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "#0F0F0F"

    // Ignore other exclusive zones and reserve none: the wallpaper spans the whole output.
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "neon-rain-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // A Region with no geometry is an empty input region: clicks/scroll pass through.
    mask: Region {}

    Image {
        id: art

        source: "file://" + win.artworkPath
        visible: false
        smooth: true
        asynchronous: false
        onStatusChanged: {
            if (status === Image.Error)
                console.warn(`neon-rain: ${win.modelData.name}: failed to load artwork ${source}`);
        }
    }

    ShaderEffect {
        id: rain

        anchors.fill: parent
        visible: art.status === Image.Ready && win.crop !== null

        property variant source: art
        property real time: win.time
        property real intensity: win.settings.intensity
        property real layers: win.settings.layers
        property real density: win.settings.density
        property real distortion: win.settings.distortion
        property real speed: win.settings.speed
        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d uvScale: win.crop ? Qt.vector2d(win.crop.uvScaleX, win.crop.uvScaleY) : Qt.vector2d(1, 1)
        property vector2d uvOffset: win.crop ? Qt.vector2d(win.crop.uvOffsetX, win.crop.uvOffsetY) : Qt.vector2d(0, 0)

        fragmentShader: Qt.resolvedUrl("shaders/rain.frag.qsb")

        // Logs every transition. Uncompiled is not a failure (see lib/diagnostics.js); only
        // Error is, and Qt fills `log` for it.
        onStatusChanged: {
            if (status === ShaderEffect.Compiled)
                win.shaderCompiledSeen = true;
            if (status === ShaderEffect.Error)
                console.warn(`neon-rain: ${win.modelData.name}: shader error: ${log}`);
            else
                console.info(`neon-rain: ${win.modelData.name}: shader status -> ${Diagnostics.shaderStatusName(status)}`);
        }
    }

    property bool shaderCompiledSeen: false

    // Frames actually presented by this surface's render loop (not timer ticks). The
    // compositor withholds frame callbacks from hidden surfaces, so this shows real cost.
    property int framesSwapped: 0

    Connections {
        target: rain.Window.window
        function onFrameSwapped() {
            win.framesSwapped++;
        }
    }

    Component.onCompleted: console.info(`neon-rain: surface for ${modelData.name}`)

    // Renders only this wallpaper item (artwork + rain) into a PNG: never windows, the bar or
    // anything else on the output, so test evidence cannot leak application contents.
    function capture(path) {
        if (!rain.visible) {
            console.warn(`neon-rain: ${modelData.name}: capture skipped, wallpaper not visible`);
            return false;
        }
        return rain.grabToImage(result => {
            if (!result.saveToFile(path))
                console.warn(`neon-rain: ${modelData.name}: cannot save capture ${path}`);
        });
    }

    function describe() {
        return {
            output: modelData.name,
            size: `${width}x${height}`,
            artwork: `${art.implicitWidth}x${art.implicitHeight}`,
            artworkStatus: ["Null", "Ready", "Loading", "Error"][art.status],
            shader: Diagnostics.shaderReport(rain.status, rain.log, shaderCompiledSeen),
            framesSwapped: framesSwapped,
            crop: crop ? {
                scale: +crop.scale.toFixed(4),
                srcX: +crop.srcX.toFixed(1),
                srcY: +crop.srcY.toFixed(1),
                srcW: +crop.srcW.toFixed(1),
                srcH: +crop.srcH.toFixed(1)
            } : null
        };
    }
}
