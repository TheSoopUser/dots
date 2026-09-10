import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property var theme
    required property var notifications
    required property var anchorItem

    anchor {
        item: root.anchorItem
        edges: Edges.Bottom | Edges.Right
        gravity: Edges.Bottom | Edges.Left
        margins.top: 10
    }

    width: 400
    height: 500
    color: "transparent"
    grabFocus: true

    Rectangle {
        id: glass
        anchors.fill: parent
        radius: root.theme.largeRadius
        color: Qt.rgba(root.theme.background.r, root.theme.background.g, root.theme.background.b, 0.78)
        border.color: Qt.rgba(root.theme.foreground.r, root.theme.foreground.g, root.theme.foreground.b, 0.11)
        border.width: 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.035)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 88
            radius: parent.radius
            color: Qt.rgba(root.theme.surfaceRaised.r, root.theme.surfaceRaised.g, root.theme.surfaceRaised.b, 0.22)

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }
        }

        Text {
            id: title
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 20
            anchors.leftMargin: 20
            text: "Notifications"
            color: root.theme.foreground
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }

        Text {
            anchors.top: title.bottom
            anchors.left: title.left
            anchors.topMargin: 3
            text: root.notifications.count === 0
                ? "You're all caught up"
                : root.notifications.count + (root.notifications.count === 1 ? " unread item" : " unread items")
            color: root.theme.mutedForeground
            font.pixelSize: 10
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: title.verticalCenter
            width: clearText.implicitWidth + 22
            height: 30
            radius: height / 2
            scale: clearMouse.pressed ? 0.96 : 1.0
            color: clearMouse.containsMouse
                ? Qt.rgba(root.theme.surfaceHover.r, root.theme.surfaceHover.g, root.theme.surfaceHover.b, 0.78)
                : Qt.rgba(root.theme.surface.r, root.theme.surface.g, root.theme.surface.b, 0.42)
            border.width: 1
            border.color: Qt.rgba(root.theme.foreground.r, root.theme.foreground.g, root.theme.foreground.b, 0.06)

            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                id: clearText
                anchors.centerIn: parent
                text: "Clear"
                color: root.theme.mutedForeground
                font.pixelSize: 11
                font.weight: Font.Medium
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.notifications.clearAll()
            }
        }

        Column {
            anchors.centerIn: parent
            visible: root.notifications.count === 0
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "✓"
                color: root.theme.accent
                font.pixelSize: 28
                font.weight: Font.Light
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"
                color: root.theme.mutedForeground
                font.pixelSize: 12
            }
        }

        ListView {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: 98
                bottomMargin: 12
                leftMargin: 12
                rightMargin: 12
            }

            visible: root.notifications.count > 0
            clip: true
            spacing: 8
            model: root.notifications.server.trackedNotifications

            delegate: Rectangle {
                id: card
                required property var modelData
                property var notification: modelData

                width: ListView.view.width
                height: 98
                radius: 18
                color: cardMouse.containsMouse
                    ? Qt.rgba(root.theme.surfaceHover.r, root.theme.surfaceHover.g, root.theme.surfaceHover.b, 0.62)
                    : Qt.rgba(root.theme.surface.r, root.theme.surface.g, root.theme.surface.b, 0.48)
                border.width: 1
                border.color: Qt.rgba(root.theme.foreground.r, root.theme.foreground.g, root.theme.foreground.b, cardMouse.containsMouse ? 0.08 : 0.04)

                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: appName
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    anchors.topMargin: 12
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    text: notification.appName !== "" ? notification.appName : "Notification"
                    color: root.theme.accent
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    id: summary
                    anchors.top: appName.bottom
                    anchors.left: parent.left
                    anchors.right: closeButton.left
                    anchors.topMargin: 4
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    text: notification.summary
                    color: root.theme.foreground
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    anchors.top: summary.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 5
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    text: notification.body
                    textFormat: Text.PlainText
                    color: root.theme.mutedForeground
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: closeButton
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 9
                    anchors.rightMargin: 9
                    width: 27
                    height: 27
                    radius: 12
                    color: closeMouse.containsMouse
                        ? Qt.rgba(root.theme.surfaceHover.r, root.theme.surfaceHover.g, root.theme.surfaceHover.b, 0.9)
                        : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: root.theme.mutedForeground
                        font.pixelSize: 17
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: notification.dismiss()
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }
        }
    }
}
