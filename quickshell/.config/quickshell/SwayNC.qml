pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// SwayNC owns notifications; this only mirrors its count/DND state and toggles its panel.
// `swaync-client -swb` pushes one JSON line per change, so there is no polling.
Singleton {
    id: root

    property int count: 0
    property bool dnd: false
    property bool inhibited: false

    function toggle(): void {
        Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
    }

    function toggleDnd(): void {
        Quickshell.execDetached(["swaync-client", "-d", "-sw"]);
    }

    Process {
        id: watcher
        running: true
        command: ["swaync-client", "-swb"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const msg = JSON.parse(line);
                    root.count = parseInt(msg.text) || 0;
                    root.dnd = String(msg.alt).startsWith("dnd");
                    root.inhibited = String(msg.alt).includes("inhibited");
                } catch (e) {
                    console.warn("SwayNC: unparsable line", line);
                }
            }
        }
        // Reconnect if SwayNC restarts.
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: watcher.running = true
    }
}
