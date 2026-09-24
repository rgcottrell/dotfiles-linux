pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: popups
    required property Theme theme
    required property NiriState niri
    readonly property int count: server.trackedNotifications.values.length

    visible: count > 0
    anchors { top: true; right: true }
    margins { top: theme.barHeight + 12; right: 12 }
    implicitWidth: Math.min(380, screen ? screen.width - 24 : 380)
    implicitHeight: Math.min(stack.implicitHeight, screen ? screen.height - theme.barHeight - 24 : 600)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dotfiles-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: false
        actionIconsSupported: false
        persistenceSupported: false
        inlineReplySupported: false
        onNotification: notification => {
            // Keep a stack on its original monitor until cleared, rather than
            // chasing focus while the user is reading or reaching for an action.
            if (popups.count === 0) {
                const focused = popups.niri.workspaces.find(w => w.is_focused);
                popups.screen = Quickshell.screens.find(s => focused && s.name === focused.output)
                    || Quickshell.screens[0];
            }
            notification.tracked = true;
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: stack.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: stack
            width: parent.width
            spacing: 10
            Repeater {
                model: server.trackedNotifications
                NotificationCard {
                    required property var modelData
                    required property int index
                    width: stack.width
                    theme: popups.theme
                    notification: modelData
                    critical: modelData.urgency === NotificationUrgency.Critical
                    visible: index < 3
                }
            }
            Rectangle {
                visible: popups.count > 3
                width: stack.width
                height: 28
                radius: 6
                color: popups.theme.panel
                Text {
                    anchors.centerIn: parent
                    text: (popups.count - 3) + " more waiting"
                    color: popups.theme.muted
                    font.family: popups.theme.font
                    font.pixelSize: 11
                }
            }
        }
    }
}
