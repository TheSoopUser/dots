import QtQuick

Rectangle {
    id: root

    required property var theme
    property string label: ""
    property color textColor: theme.foreground
    signal clicked()
    signal wheelUp()
    signal wheelDown()

    height: 28
    width: labelText.implicitWidth + 20
    radius: height / 2
    scale: mouse.pressed ? 0.96 : mouse.containsMouse ? 1.02 : 1.0

    color: mouse.containsMouse
        ? Qt.rgba(theme.surfaceHover.r, theme.surfaceHover.g, theme.surfaceHover.b, 0.72)
        : Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.28)

    border.width: 1
    border.color: mouse.containsMouse
        ? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.08)
        : Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.035)

    Behavior on scale {
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: 130 }
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: root.label
        color: root.textColor
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.wheelUp()
            else
                root.wheelDown()
        }
    }
}
