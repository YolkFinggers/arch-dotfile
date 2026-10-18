import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// One bar per screen, drawn as three islands hanging from the top edge of a transparent full-width window.
// Left: workspaces + active title, flat on the left screen edge. Center: clock. Right: tray and status,
// flat on the right screen edge. Each island is sized to its content and ends in slanted blades
// (Island.qml); the space between islands is empty and clicks through.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property bool compact: modelData.width < Theme.compactWidth
    // Wayland foreign-toplevel state is available at startup; Hyprland's activeToplevel
    // stays null until the first focus event.
    readonly property Toplevel toplevel: {
        const t = ToplevelManager.activeToplevel;
        return t && t.activated && t.screens.includes(modelData) ? t : null;
    }

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    // Preview mode reserves nothing, so it sits under Waybar without shifting windows.
    exclusionMode: Theme.preview ? ExclusionMode.Normal : ExclusionMode.Auto
    exclusiveZone: Theme.preview ? 0 : implicitHeight
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Input only lands on the islands; the transparent gaps pass clicks to the windows below.
    // Region has no polygons, so each island is a full-height body between its bottom corners
    // plus an upper half reaching halfway into each blade. Islands are direct children, so x is window-relative.
    mask: Region {
        Region {
            x: leftIsland.x + leftIsland.bottomLeft
            width: leftIsland.bottomRight - leftIsland.bottomLeft
            height: leftIsland.height
        }
        Region {
            x: leftIsland.x + leftIsland.bottomLeft / 2
            width: (leftIsland.width + leftIsland.bottomRight - leftIsland.bottomLeft) / 2
            height: leftIsland.height / 2
        }
        Region {
            x: centerIsland.x + centerIsland.bottomLeft
            width: centerIsland.bottomRight - centerIsland.bottomLeft
            height: centerIsland.height
        }
        Region {
            x: centerIsland.x + centerIsland.bottomLeft / 2
            width: (centerIsland.width + centerIsland.bottomRight - centerIsland.bottomLeft) / 2
            height: centerIsland.height / 2
        }
        Region {
            x: rightIsland.x + rightIsland.bottomLeft
            width: rightIsland.bottomRight - rightIsland.bottomLeft
            height: rightIsland.height
        }
        Region {
            x: rightIsland.x + rightIsland.bottomLeft / 2
            width: (rightIsland.width + rightIsland.bottomRight - rightIsland.bottomLeft) / 2
            height: rightIsland.height / 2
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Left: workspaces + title. The title is capped and elided so the island stops short of the clock.
    Island {
        id: leftIsland
        x: 0
        rightBlade: true
        content: left

        Row {
            id: left
            anchors.centerIn: parent
            spacing: 8

            Workspaces {
                id: workspaces
                monitor: bar.monitor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: title
                // Space left before the clock island, after the gap, both facing fin sets and this island's padding.
                readonly property real room: centerIsland.x - Theme.islandGap - 2 * Theme.finSpan - leftIsland.x - leftIsland.leftInset - leftIsland.rightInset - workspaces.width - left.spacing
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(Math.ceil(implicitWidth), Math.floor(room), bar.compact ? Theme.titleMaxCompact : Theme.titleMax))
                visible: text !== "" && width > 24
                text: bar.toplevel?.title ?? ""
                elide: Text.ElideRight
                color: Theme.silver
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }
    }

    // Center: clock (time only on compact screens).
    Island {
        id: centerIsland
        x: Math.round((bar.width - width) / 2)
        leftBlade: true
        rightBlade: true
        rightFins: rightIsland.leftFins
        content: center

        Pill {
            id: center
            anchors.centerIn: parent
            interactive: false
            icon: bar.compact ? "" : "󰥔"
            label: bar.compact ? Qt.formatDateTime(clock.date, "HH:mm") : Qt.formatDateTime(clock.date, "HH:mm  ·  ddd d MMM")
            labelColor: Theme.text
        }
    }

    // Right: tray, network, volume, battery, SwayNC. An empty tray and a missing battery take no space.
    Island {
        id: rightIsland
        x: bar.width - width
        leftBlade: true
        // The right island is not width-capped, so its fins and the clock's facing fins drop when crowded.
        leftFins: x - centerIsland.x - centerIsland.width >= 2 * Theme.finSpan + Theme.islandGap
        content: right

        Row {
            id: right
            anchors.centerIn: parent
            spacing: 2

            TrayItems {
                id: tray
                bar: bar
                visible: count > 0
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                visible: tray.visible
                width: 1
                height: Theme.barHeight - 16
                color: Theme.edge
                anchors.verticalCenter: parent.verticalCenter
            }

            Pill {
                anchors.verticalCenter: parent.verticalCenter
                interactive: false
                icon: Net.icon
                iconColor: Net.connected ? Theme.icon : Theme.urgent
                label: bar.compact ? "" : Net.label
            }

            Pill {
                anchors.verticalCenter: parent.verticalCenter
                icon: Audio.icon
                iconColor: Audio.muted ? Theme.textDim : Theme.icon
                label: Audio.ready ? `${Math.round(Audio.volume * 100)}%` : "–"
                labelColor: Audio.muted ? Theme.textDim : Theme.text
                onClicked: m => {
                    if (m.button === Qt.RightButton)
                        Quickshell.execDetached(["pavucontrol"]);
                    else
                        Audio.toggleMute();
                }
                onScrolled: d => Audio.step(d * 0.05)
            }

            Pill {
                visible: Power.present
                anchors.verticalCenter: parent.verticalCenter
                interactive: false
                icon: Power.icon
                iconColor: Power.low ? Theme.urgent : Power.charging ? Theme.cyan : Theme.icon
                label: `${Math.round(Power.percent)}%`
            }

            Pill {
                anchors.verticalCenter: parent.verticalCenter
                icon: SwayNC.dnd ? "󰂛" : SwayNC.count > 0 ? "󰂚" : "󰂜"
                iconColor: SwayNC.dnd ? Theme.textDim : Theme.icon
                label: SwayNC.count > 0 ? String(SwayNC.count) : ""
                onClicked: m => m.button === Qt.RightButton ? SwayNC.toggleDnd() : SwayNC.toggle()
            }
        }
    }
}
