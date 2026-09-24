pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: card
    required property Theme theme
    required property var notification
    property bool critical: false
    readonly property int timeout: critical || notification.expireTimeout === 0 ? 0
        : notification.expireTimeout < 0 ? 5000 : notification.expireTimeout

    implicitHeight: content.implicitHeight + 28
    radius: 10
    color: theme.panel
    border.width: 1
    border.color: critical ? theme.warning : theme.hover

    // Only visible cards age; queued cards get their full time when displayed.
    // Hovering pauses expiry, and leaving gives a fresh reading interval.
    HoverHandler { id: hover }
    Timer {
        id: expiry
        interval: Math.max(1, card.timeout)
        running: card.visible && card.timeout > 0 && !hover.hovered
        onTriggered: card.notification.expire()
    }
    function refresh() {
        if (card.visible && card.timeout > 0 && !hover.hovered) expiry.restart();
    }
    Connections {
        target: card.notification
        function onSummaryChanged() { card.refresh(); }
        function onBodyChanged() { card.refresh(); }
        function onActionsChanged() { card.refresh(); }
        function onExpireTimeoutChanged() { card.refresh(); }
        function onUrgencyChanged() { card.refresh(); }
    }

    MouseArea {
        objectName: "dismissArea"
        anchors.fill: parent
        onClicked: card.notification.dismiss()
    }
    Column {
        id: content
        x: 14; y: 14
        width: parent.width - 28
        spacing: 8
        Item {
            width: parent.width
            height: 24
            Text {
                anchors { left: parent.left; right: close.left; verticalCenter: parent.verticalCenter }
                text: card.notification.appName || "Notification"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: card.critical ? card.theme.warning : card.theme.accent
                font.family: card.theme.font
                font.pixelSize: 11
            }
            BarButton {
                id: close
                anchors.right: parent.right
                theme: card.theme
                text: "×"
                focusPolicy: Qt.NoFocus
                Accessible.name: "Dismiss notification"
                onClicked: card.notification.dismiss()
            }
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: card.notification.summary
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: card.theme.text
            font.family: card.theme.font
            font.pixelSize: 14
            font.bold: true
        }
        Text {
            width: parent.width
            visible: text.length > 0
            text: card.notification.body
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: card.theme.text
            font.family: card.theme.font
            font.pixelSize: 12
        }
        Flow {
            width: parent.width
            spacing: 6
            visible: card.notification.actions.length > 0
            Repeater {
                model: card.notification.actions
                AbstractButton {
                    id: actionButton
                    required property var modelData
                    objectName: "notificationAction"
                    width: Math.min(implicitWidth, content.width)
                    implicitWidth: actionLabel.implicitWidth + 20
                    implicitHeight: 30
                    hoverEnabled: true
                    focusPolicy: Qt.NoFocus
                    text: modelData.text || (modelData.identifier === "default" ? "Open" : "Action")
                    onClicked: modelData.invoke()
                    background: Rectangle {
                        radius: 5
                        color: actionButton.hovered ? card.theme.accent : card.theme.hover
                    }
                    contentItem: Text {
                        id: actionLabel
                        text: actionButton.text
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: actionButton.hovered ? card.theme.background : card.theme.text
                        font.family: card.theme.font
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
