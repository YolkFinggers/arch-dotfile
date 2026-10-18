import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// StatusNotifier tray. Left click activates (or opens the menu for menu-only items),
// right click opens the item's DBus menu, middle click is secondary activate.
Row {
    id: root

    required property var bar
    readonly property int count: items.count

    spacing: 2

    Repeater {
        id: items
        model: SystemTray.items

        Rectangle {
            id: slot
            required property SystemTrayItem modelData

            width: Theme.barHeight - 10
            height: width
            radius: Theme.pillRadius
            color: area.containsMouse ? Theme.surfaceHover : "transparent"
            border.width: modelData.status === Status.NeedsAttention ? 1 : 0
            border.color: Theme.urgent

            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.iconSize
                source: slot.modelData.icon
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: m => {
                    const item = slot.modelData;
                    if (m.button === Qt.MiddleButton)
                        item.secondaryActivate();
                    else if (m.button === Qt.RightButton || item.onlyMenu)
                        slot.openMenu();
                    else
                        item.activate();
                }
                onWheel: w => slot.modelData.scroll(w.angleDelta.y / 120, false)
            }

            function openMenu(): void {
                if (!modelData.hasMenu)
                    return;
                const p = slot.mapToItem(root.bar.contentItem, 0, slot.height + 6);
                modelData.display(root.bar, p.x, p.y);
            }
        }
    }
}
