pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Read-only NetworkManager status via Quickshell.Networking (no nmcli polling).
Singleton {
    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null
    readonly property var wifiNetwork: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null

    // Some backends report 0..1, others 0..100.
    readonly property int signal: {
        const s = wifiNetwork?.signalStrength ?? 0;
        return Math.round(s <= 1 ? s * 100 : s);
    }

    readonly property bool connected: wired !== null || wifi !== null
    readonly property string name: wired ? wired.name : wifiNetwork ? wifiNetwork.name : wifi ? wifi.name : ""
    readonly property string icon: wired ? "󰈀" : wifi ? (signal >= 67 ? "󰤨" : signal >= 34 ? "󰤢" : "󰤟") : "󰤮"
    readonly property string label: !connected ? "offline" : wired ? name : `${name} ${signal}%`
}
