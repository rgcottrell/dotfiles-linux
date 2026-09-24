import QtQuick
import Quickshell
import Quickshell.Io

// One event stream shared by all monitors. Niri sends a full snapshot on connect.
QtObject {
    id: state
    property var workspaces: []

    function accept(line) {
        try {
            const event = JSON.parse(line);
            if (event.WorkspacesChanged) {
                workspaces = event.WorkspacesChanged.workspaces.sort((a, b) => a.idx - b.idx);
            } else if (event.WorkspaceActivated) {
                const active = event.WorkspaceActivated;
                const target = workspaces.find(w => w.id === active.id);
                if (!target) return;
                workspaces = workspaces.map(w => Object.assign({}, w, {
                    is_active: w.output === target.output ? w.id === active.id : w.is_active,
                    is_focused: active.focused ? w.id === active.id : w.is_focused
                }));
            }
        } catch (error) {
            console.warn("Invalid Niri event:", error);
        }
    }

    function focus(workspace) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(workspace.idx)]);
    }

    property Process events: Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser { onRead: data => state.accept(data) }
        onExited: {
            state.workspaces = [];
            state.reconnect.start();
        }
    }
    property Timer reconnect: Timer {
        interval: 1500
        onTriggered: state.events.running = true
    }
}
