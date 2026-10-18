import QtQuick
import Quickshell.Hyprland

// Workspaces living on this bar's monitor. Clicking uses HyprlandWorkspace.activate(),
// which Quickshell 0.3.2 sends as a Lua dispatch (hl.dsp.focus) when Hyprland runs Lua config.
Row {
    id: root

    required property HyprlandMonitor monitor

    spacing: 3

    Repeater {
        model: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor).sort((a, b) => a.id - b.id)

        Rectangle {
            id: chip
            required property HyprlandWorkspace modelData
            readonly property bool shown: root.monitor?.activeWorkspace === modelData
            readonly property bool focused: modelData.focused

            width: Math.max(24, label.implicitWidth + 14)
            height: Theme.barHeight - 10
            radius: Theme.pillRadius
            color: focused ? Theme.silverDim : hover.containsMouse ? Theme.surfaceHover : shown ? Theme.surfaceRaised : "transparent"
            border.width: focused || shown || modelData.urgent ? 1 : 0
            border.color: modelData.urgent ? Theme.urgent : focused ? Theme.silver : Theme.edgeStrong

            Text {
                id: label
                anchors.centerIn: parent
                text: chip.modelData.name
                color: chip.modelData.urgent ? Theme.urgent : chip.focused ? Theme.silver : chip.shown ? Theme.textSoft : Theme.textDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: chip.focused
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.modelData.activate()
            }
        }
    }
}
