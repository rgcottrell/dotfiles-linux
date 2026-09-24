import QtQuick
import QtQuick.Controls

AbstractButton {
    id: button
    required property Theme theme
    property bool highlighted: false

    implicitWidth: label.implicitWidth + 18
    implicitHeight: 26
    hoverEnabled: true
    contentItem: Text {
        id: label
        text: button.text
        color: button.highlighted ? button.theme.background : button.theme.text
        font.family: button.theme.font
        font.pixelSize: button.theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 5
        color: button.highlighted ? button.theme.accent
             : button.hovered || button.activeFocus ? button.theme.hover : "transparent"
    }
}
