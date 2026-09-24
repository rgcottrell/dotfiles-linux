pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "AppSearch.js" as AppSearch

PanelWindow {
    id: launcher
    required property Theme theme
    required property NiriState niri
    property var applications: DesktopEntries.applications.values
    readonly property var matches: AppSearch.search(applications, search.text)
    property int selected: 0

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#55000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dotfiles-launcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function toggle(targetScreen) {
        if (visible) { visible = false; return; }
        const workspace = niri.workspaces.find(w => w.is_focused);
        screen = targetScreen || Quickshell.screens.find(s => workspace && s.name === workspace.output)
            || Quickshell.screens[0];
        search.text = "";
        selected = 0;
        visible = true;
        Qt.callLater(() => search.forceActiveFocus());
    }

    function moveSelection(delta) {
        if (matches.length === 0) return;
        selected = (selected + delta + matches.length) % matches.length;
        results.positionViewAtIndex(selected, ListView.Contain);
    }

    function launch(index) {
        const app = matches[index];
        if (!app) return;
        visible = false;
        if (app.runInTerminal) {
            const cwd = app.workingDirectory || Quickshell.env("HOME");
            Quickshell.execDetached(["ghostty", "--working-directory=" + cwd, "-e"].concat(app.command));
        } else {
            app.execute();
        }
    }

    onMatchesChanged: {
        selected = 0;
        results.positionViewAtBeginning();
    }

    MouseArea { anchors.fill: parent; onClicked: launcher.visible = false }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(12, Math.min(parent.height * 0.18, (parent.height - height) / 2))
        width: Math.min(560, parent.width - 24)
        height: Math.min(content.implicitHeight + 32, parent.height - 24)
        radius: 12
        color: launcher.theme.panel
        border.color: launcher.theme.accent
        border.width: 1
        // Clicking padding inside the card must not dismiss the launcher.
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12
            TextField {
                id: search
                width: parent.width
                height: 44
                placeholderText: "Search applications…"
                color: launcher.theme.text
                placeholderTextColor: launcher.theme.muted
                selectionColor: launcher.theme.accent
                selectedTextColor: launcher.theme.background
                font.family: launcher.theme.font
                font.pixelSize: 16
                leftPadding: 12
                rightPadding: 12
                background: Rectangle { color: launcher.theme.background; radius: 6 }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) launcher.visible = false;
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) launcher.moveSelection(1);
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) launcher.moveSelection(-1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) launcher.launch(launcher.selected);
                    else return;
                    event.accepted = true;
                }
            }
            ListView {
                id: results
                width: parent.width
                // Leave room for the search field, footer, padding and gaps.
                height: Math.min(Math.min(launcher.matches.length, 7) * 54,
                                 Math.max(0, launcher.height - 150))
                clip: true
                model: launcher.matches
                currentIndex: launcher.selected
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: results.width
                    height: 54
                    radius: 6
                    color: index === launcher.selected ? launcher.theme.hover : "transparent"
                    Image {
                        id: icon
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 30
                        source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                        sourceSize.width: 30; sourceSize.height: 30
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        anchors.centerIn: icon
                        visible: icon.status !== Image.Ready
                        text: "󰀻"
                        color: launcher.theme.accent
                        font.family: launcher.theme.font
                        font.pixelSize: 24
                    }
                    Column {
                        x: 54; width: parent.width - 70
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: row.modelData.name
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: launcher.theme.text
                            font.family: launcher.theme.font
                            font.pixelSize: 14
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: row.modelData.genericName || row.modelData.comment || ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: launcher.theme.muted
                            font.family: launcher.theme.font
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: launcher.launch(row.index)
                    }
                }
            }
            Text {
                width: parent.width
                text: launcher.matches.length ? "↑↓ select    Enter launch    Esc close" : "No applications found"
                color: launcher.theme.muted
                font.family: launcher.theme.font
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
