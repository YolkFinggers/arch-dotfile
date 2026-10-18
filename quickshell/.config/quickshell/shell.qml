//@ pragma UseQApplication
// UseQApplication: tray menus (SystemTrayItem.display) need a QApplication.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // `qs ipc call bar <fn>`: drive the same code paths the bar's mouse actions use.
    IpcHandler {
        target: "bar"

        function focusWorkspace(id: int): void {
            const ws = Hyprland.workspaces.values.find(w => w.id === id);
            if (ws)
                ws.activate();
        }
        function toggleNotifications(): void {
            SwayNC.toggle();
        }
        function volumeStep(delta: real): void {
            Audio.step(delta);
        }
        function toggleMute(): void {
            Audio.toggleMute();
        }
        function status(): string {
            return JSON.stringify({
                screens: Quickshell.screens.map(s => `${s.name} ${s.width}x${s.height}`),
                focusedWorkspace: Hyprland.focusedWorkspace?.id ?? null,
                workspaces: Hyprland.workspaces.values.map(w => `${w.id}@${w.monitor?.name}`),
                title: ToplevelManager.activeToplevel?.title ?? "",
                usingLua: Hyprland.usingLua,
                volume: Audio.ready ? Math.round(Audio.volume * 100) : null,
                muted: Audio.muted,
                network: Net.label,
                battery: Power.present ? Math.round(Power.percent) : null,
                batteryState: Power.present ? Power.stateText : null,
                notifications: SwayNC.count,
                dnd: SwayNC.dnd,
                tray: SystemTray.items.values.map(i => `${i.id}${i.hasMenu ? " (menu)" : ""}`)
            });
        }    }
}
