pragma Singleton

import QtQuick
import Quickshell

// Neon Rain palette, shared with SwayNC (swaync/style.css) so bar and notifications match.
Singleton {
    // Surfaces: translucent near-black violet
    readonly property color surface: Qt.rgba(14 / 255, 10 / 255, 24 / 255, 0.86)
    readonly property color surfaceRaised: Qt.rgba(34 / 255, 24 / 255, 56 / 255, 0.72)
    readonly property color surfaceHover: Qt.rgba(52 / 255, 36 / 255, 86 / 255, 0.75)

    // Edges: violet
    readonly property color edge: Qt.rgba(157 / 255, 108 / 255, 255 / 255, 0.30)
    readonly property color edgeStrong: Qt.rgba(157 / 255, 108 / 255, 255 / 255, 0.70)
    readonly property color violet: "#8c5cf6"

    // Status glyphs (clock, network, audio, battery, notifications). Labels keep `text`;
    // warning, muted and disconnected states override this per module.
    readonly property color icon: violet

    // Focus: silver from the Hyprland active_border gradient (rgba(192,192,192,0.9) in hyprland.lua),
    // so the focused workspace and window title match the focused window's border.
    readonly property color silver: "#c0c0c0"
    readonly property color silverDim: Qt.rgba(192 / 255, 192 / 255, 192 / 255, 0.16)

    // Accents: cyan for interactive / status, pink for urgent
    readonly property color cyan: "#4de8ff"
    readonly property color cyanDim: Qt.rgba(77 / 255, 232 / 255, 255 / 255, 0.16)
    readonly property color urgent: "#ff5ca0"
    readonly property color warn: "#ffb35c"

    // Text
    readonly property color text: "#e2dcf5"
    readonly property color textSoft: "#d6c4ff"
    readonly property color textDim: "#8c7eb4"

    readonly property string font: "0xProto Nerd Font Propo"
    readonly property int fontSize: 13
    readonly property int iconSize: 16

    readonly property int barHeight: 32
    readonly property int gap: 4
    readonly property int radius: 10
    readonly property int pillRadius: 7
    // Horizontal run of an island's slanted blade end, top corner to bottom corner.
    readonly property int blade: 14
    // Fins trailing out past each blade: three solid slanted blades (//// // /), wide to narrow and
    // shorter toward the tip. finGroups sets each blade's width in finWidth units; the last one ends
    // in a triangular cap pointing outward (/>). Offsets are horizontal, measured outward from the
    // island blade's top corner.
    readonly property int finLead: 4
    readonly property int finWidth: 3
    readonly property int finGroupGap: 5
    readonly property var finGroups: [4, 2, 1]
    readonly property var finHeights: [1.0, 0.72, 0.46]
    // How far the cap's tip juts out from the narrow blade's outer edge, at half its height.
    readonly property int finCap: 6
    // Total outward reach of one fin set; neighbors keep this much extra space clear.
    readonly property int finSpan: finLead + 7 * finWidth + 2 * finGroupGap + finCap
    // Minimum transparent space between islands, and the title's width cap.
    readonly property int islandGap: 8
    readonly property int titleMax: 520
    readonly property int titleMaxCompact: 260

    // Screens narrower than this (e.g. the portrait HDMI-A-1) drop secondary labels.
    readonly property int compactWidth: 1400

    // QS_BAR_PREVIEW=1: reserve no space, so the bar can be tested next to Waybar.
    readonly property bool preview: Quickshell.env("QS_BAR_PREVIEW") === "1"
}
