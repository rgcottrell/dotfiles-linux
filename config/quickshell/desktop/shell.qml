pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    Theme { id: desktopTheme }
    NiriState { id: workspaceState }
    SystemClock { id: wallClock; precision: SystemClock.Minutes }
    Launcher { id: appLauncher; theme: desktopTheme; niri: workspaceState }
    Notifications { id: notifications; theme: desktopTheme; niri: workspaceState }

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: output
            required property var modelData
            PanelWindow {
                screen: output.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                color: desktopTheme.background
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "dotfiles-background"
                mask: Region {}
            }
            Bar {
                screen: output.modelData; theme: desktopTheme; niri: workspaceState; clock: wallClock
                onLauncherRequested: appLauncher.toggle(output.modelData)
            }
        }
    }

    IpcHandler {
        target: "desktop"
        function launcher(): void { appLauncher.toggle(null); }
        function status(): string {
            return JSON.stringify({ screens: Quickshell.screens.length, workspaces: workspaceState.workspaces,
                launcherVisible: appLauncher.visible, applications: appLauncher.applications.length,
                notifications: notifications.count });
        }
    }
}
