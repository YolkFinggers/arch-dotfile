pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery via UPower DisplayDevice. Hidden on machines without a battery.
Singleton {
    readonly property var device: UPower.displayDevice
    readonly property bool present: (device?.ready ?? false) && device.isLaptopBattery && device.isPresent
    // UPower reports percentage as 0..1 in Quickshell; normalise to 0..100.
    readonly property real percent: {
        const p = device?.percentage ?? 0;
        return p <= 1 ? p * 100 : p;
    }
    readonly property bool charging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property string stateText: device ? UPowerDeviceState.toString(device.state) : ""
    readonly property bool low: present && !charging && percent <= 15
    readonly property string icon: charging ? "󰂄" : full ? "󰁹" : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.min(10, Math.floor(percent / 10))]
}
