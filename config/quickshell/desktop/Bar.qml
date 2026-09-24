pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PanelWindow {
    id: bar
    required property Theme theme
    required property NiriState niri
    required property SystemClock clock
    signal launcherRequested()
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var battery: UPower.displayDevice

    anchors { top: true; left: true; right: true }
    implicitHeight: theme.barHeight
    exclusiveZone: theme.barHeight
    color: theme.panel
    WlrLayershell.namespace: "dotfiles-bar"
    WlrLayershell.layer: WlrLayer.Top

    PwObjectTracker { objects: bar.sink ? [bar.sink] : [] }

    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        BarButton {
            theme: bar.theme
            text: ""
            onClicked: bar.launcherRequested()
        }
        Repeater {
            model: bar.niri.workspaces.filter(w => w.output === bar.screen.name)
            BarButton {
                required property var modelData
                theme: bar.theme
                text: String(modelData.idx)
                highlighted: modelData.is_active
                onClicked: bar.niri.focus(modelData)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        // Drop the center clock before it overlaps either side on narrow outputs.
        visible: parent.width > 2 * Math.max(left.width, right.width) + implicitWidth + 32
        text: Qt.formatDateTime(bar.clock.date, "ddd  dd MMM  HH:mm")
        color: bar.theme.text
        font.family: bar.theme.font
        font.pixelSize: bar.theme.fontSize
    }

    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        BarButton {
            theme: bar.theme
            text: !bar.sink || !bar.sink.audio ? "Audio —"
                : bar.sink.audio.muted ? "󰖁 Muted"
                : "󰕾 " + Math.round(bar.sink.audio.volume * 100) + "%"
            onClicked: {
                if (bar.sink && bar.sink.audio) bar.sink.audio.muted = !bar.sink.audio.muted;
            }
            WheelHandler {
                onWheel: event => {
                    if (bar.sink && bar.sink.audio)
                        bar.sink.audio.volume = Math.max(0, Math.min(1,
                            bar.sink.audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05)));
                }
            }
        }
        BarButton {
            theme: bar.theme
            visible: bar.battery.isPresent && bar.battery.isLaptopBattery
            text: (bar.battery.state === UPowerDeviceState.Charging ? "󰂄 " : "󰁹 ")
                + Math.round(bar.battery.percentage * 100) + "%"
            highlighted: bar.battery.percentage < 0.15
        }
        BarButton {
            theme: bar.theme
            text: "󰌾"
            onClicked: Quickshell.execDetached(["swaylock", "-f"])
        }
    }
}
