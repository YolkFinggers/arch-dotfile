pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default PipeWire sink, event-driven (no polling).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.ready ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string icon: muted || volume <= 0 ? "󰝟" : volume < 0.34 ? "󰕿" : volume < 0.67 ? "󰖀" : "󰕾"

    function step(delta: real): void {
        if (!ready)
            return;
        sink.audio.volume = Math.max(0, Math.min(1, Math.round((volume + delta) * 100) / 100));
    }

    function toggleMute(): void {
        if (ready)
            sink.audio.muted = !sink.audio.muted;
    }

    // Node properties are only live while the node is bound by a tracker.
    PwObjectTracker {
        objects: [root.sink]
    }
}
