import QtQuick
import Quickshell.Hyprland

Rectangle {
    id: root

    required property var theme
    required property int workspaceNumber

    property bool active: Hyprland.focusedWorkspace
        && Hyprland.focusedWorkspace.id === workspaceNumber

    width: active ? 34 : 27
    height: 27
    radius: height / 2
    scale: mouse.pressed ? 0.94 : mouse.containsMouse ? 1.04 : 1.0

    color: active
        ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.92)
        : mouse.containsMouse
            ? Qt.rgba(theme.surfaceHover.r, theme.surfaceHover.g, theme.surfaceHover.b, 0.72)
            : "transparent"

    border.width: 1
    border.color: active
        ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.55)
        : mouse.containsMouse
            ? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.07)
            : "transparent"

    Behavior on width {
        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: 130 }
    }

    Text {
        anchors.centerIn: parent
        text: root.workspaceNumber
        color: root.active ? root.theme.background : root.theme.mutedForeground
        font.pixelSize: 11
        font.weight: root.active ? Font.Bold : Font.Medium
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (Hyprland.usingLua)
                Hyprland.dispatch("hl.dsp.focus({ workspace = " + root.workspaceNumber + " })")
            else
                Hyprland.dispatch("workspace " + root.workspaceNumber)
        }
    }
}
