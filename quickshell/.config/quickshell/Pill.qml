import QtQuick

// Small interactive chip: icon + optional label. Violet icon (Theme.icon) by default, neutral label.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Theme.icon
    property color labelColor: Theme.text
    property bool interactive: true

    signal clicked(var mouse)
    signal scrolled(real delta)

    implicitWidth: row.implicitWidth + 16
    implicitHeight: Theme.barHeight - 10
    radius: Theme.pillRadius
    color: mouse.containsMouse && interactive ? Theme.surfaceHover : "transparent"
    border.width: mouse.containsMouse && interactive ? 1 : 0
    border.color: Theme.edgeStrong

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor
            font.family: Theme.font
            font.pixelSize: Theme.iconSize
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: root.label !== ""
            text: root.label
            color: root.labelColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y / 120)
    }
}
