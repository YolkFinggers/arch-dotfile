import QtQuick
import Quickshell
import Quickshell.Wayland
import "lib/geometry.js" as Geometry
import "lib/profiles.js" as Profiles

// City Mode surface for one output (M2). Mapped only while City Mode is open: an Overlay
// layer showing the same artwork, crop and rain as the wallpaper beneath, plus building
// hotspots from config/city.json. Workspaces are never switched to show it, so every
// monitor keeps its workspace and closing it reveals exactly what was there before.
//
// Input: the whole surface takes pointer input while open (closed = unmapped, so nothing is
// intercepted in normal use). Keyboard: exclusive only on the output that was focused when
// City Mode opened, so ESC works there; other outputs never take the keyboard.
PanelWindow {
    id: win

    required property ShellScreen modelData
    required property string artworkPath
    property var settings
    property var config
    property var city
    property real time
    property bool open: false
    property string keyboardOutput: ""
    // city-ctl status result: { buildings: [...] } or null while loading.
    property var status: null

    signal activate(string buildingId)
    signal dismiss

    readonly property bool ownsKeyboard: open && keyboardOutput === modelData.name
    readonly property var cropFocus: Profiles.outputFocus(config, modelData.name)
    readonly property var crop: Geometry.coverCrop(art.implicitWidth, art.implicitHeight, width, height, cropFocus.focusX, cropFocus.focusY)

    function buildingStatus(id) {
        if (!status || !status.buildings)
            return null;
        return status.buildings.find(b => b.id === id) || null;
    }

    screen: modelData
    visible: open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "#0F0F0F"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "neon-rain-city"
    WlrLayershell.keyboardFocus: ownsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOwnsKeyboardChanged: if (ownsKeyboard) keys.forceActiveFocus()

    Image {
        id: art

        source: "file://" + win.artworkPath
        visible: false
        smooth: true
        asynchronous: false
    }

    // Same shader and uniforms as RainWallpaper, so the city is pixel-for-pixel the same scene.
    ShaderEffect {
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
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.dismiss()
    }

    Repeater {
        model: win.crop && win.city ? win.city.buildings : []

        Item {
            id: spot

            required property var modelData
            readonly property var topLeft: Geometry.imageToView(win.crop, modelData.rect.x, modelData.rect.y)
            readonly property var st: win.buildingStatus(modelData.id)

            x: topLeft.x
            y: topLeft.y
            width: modelData.rect.w * win.crop.scale
            height: modelData.rect.h * win.crop.scale
            // Hidden when the building is cropped out of this output.
            visible: x + width > 0 && y + height > 0 && x < win.width && y < win.height

            Rectangle {
                anchors.fill: parent
                color: "#6E3CBC"
                opacity: mouse.containsMouse ? 0.22 : 0.06
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: "#8C5CF6"
                border.width: mouse.containsMouse ? 2 : 1
                opacity: mouse.containsMouse ? 0.95 : 0.4
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.activate(spot.modelData.id)
            }

            // Hover card: only discovered facts from city-ctl status.
            Rectangle {
                visible: mouse.containsMouse
                x: spot.x + spot.width + 12 + width > win.width ? -width - 12 : spot.width + 12
                y: 0
                width: 300
                height: card.implicitHeight + 20
                color: "#E60F0F0F"
                border.color: "#8C5CF6"
                border.width: 1

                Column {
                    id: card

                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 4

                    Text {
                        text: spot.modelData.label
                        color: "#E6E0FF"
                        font.family: "monospace"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Text {
                        text: spot.modelData.subtitle || ""
                        color: "#C0C0C0"
                        font.family: "monospace"
                        font.pixelSize: 12
                    }
                    Text {
                        text: {
                            const s = spot.st;
                            if (!s)
                                return "status: loading…";
                            if (s.error)
                                return "status: error";
                            return `WS ${s.workspace} → ${s.assignedMonitor || "any monitor"}`;
                        }
                        color: "#C0C0C0"
                        font.family: "monospace"
                        font.pixelSize: 12
                    }
                    Text {
                        text: {
                            const s = spot.st;
                            if (!s || s.error)
                                return "";
                            return `${s.state.toUpperCase()} · ${s.sessionsRunning} session(s) · ${s.windows.length} window(s)`;
                        }
                        color: spot.st && spot.st.state === "running" ? "#8C5CF6" : "#C0C0C0"
                        font.family: "monospace"
                        font.pixelSize: 12
                    }
                    Text {
                        text: spot.st && !spot.st.error ? (spot.st.windows.length ? "click: focus existing window" : "click: attach session") : ""
                        color: "#8C8C9C"
                        font.family: "monospace"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 18
        text: win.ownsKeyboard ? "CITY MODE · ESC or SUPER+U to return" : "CITY MODE"
        color: "#C0C0C0"
        opacity: 0.7
        font.family: "monospace"
        font.pixelSize: 12
        font.letterSpacing: 2
    }

    function describe() {
        return {
            output: modelData.name,
            mapped: visible,
            size: `${width}x${height}`,
            ownsKeyboard: ownsKeyboard,
            hotspots: (win.crop && win.city ? win.city.buildings : []).map(b => {
                const p = Geometry.imageToView(win.crop, b.rect.x, b.rect.y);
                return { id: b.id, x: Math.round(p.x), y: Math.round(p.y), w: Math.round(b.rect.w * win.crop.scale), h: Math.round(b.rect.h * win.crop.scale) };
            })
        };
    }

    // Grabs only this overlay's own item tree (city + hotspots), never windows underneath.
    function capture(path) {
        return contentItem.grabToImage(result => result.saveToFile(path));
    }
}
