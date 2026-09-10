import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var theme
    required property var anchorItem

    WlrLayershell.namespace: "quickshell-shell"

    // ─────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────

    property real reveal: 0.0
    property bool opened: false

    // Keep launcher on the same monitor as the bar.
    screen: root.anchorItem.QSWindow.window.screen

    // ─────────────────────────────────────────────
    // Window placement
    // ─────────────────────────────────────────────

    anchors {
        right: true
        bottom: true
    }

    margins {
        right: 16
        bottom: 16
    }

    implicitWidth: 460
    implicitHeight: 500

    exclusionMode: ExclusionMode.Ignore

    aboveWindows: true
    focusable: true

    color: "transparent"
    surfaceFormat.opaque: false

    visible: false

    // Only the currently visible launcher surface
    // should receive pointer input.
    mask: Region {
        item: launcherSurface
    }

    // ─────────────────────────────────────────────
    // Public controls
    // ─────────────────────────────────────────────

    function openLauncher() {
        closeAnimation.stop()

        root.opened = true

        if (!root.visible) {
            root.reveal = 0.0
            root.visible = true
        }

        search.text = ""
        list.currentIndex = 0

        openAnimation.restart()

        Qt.callLater(function() {
            search.forceActiveFocus()
        })
    }

    function closeLauncher() {
        if (!root.visible)
            return

        openAnimation.stop()

        root.opened = false
        closeAnimation.restart()
    }

    function toggle() {
        if (root.opened)
            root.closeLauncher()
        else
            root.openLauncher()
    }

    /*
     * Compatibility with your current Bar.qml.
     *
     * If something directly sets visible = true instead
     * of calling openLauncher(), still perform the
     * opening animation.
     */
    onVisibleChanged: {
        if (root.visible && !root.opened) {
            root.opened = true
            root.reveal = 0.0

            search.text = ""
            list.currentIndex = 0

            openAnimation.restart()

            Qt.callLater(function() {
                search.forceActiveFocus()
            })
        }

        if (!root.visible) {
            root.opened = false
            root.reveal = 0.0
        }
    }

    // ─────────────────────────────────────────────
    // Animations
    // ─────────────────────────────────────────────

    NumberAnimation {
        id: openAnimation

        target: root
        property: "reveal"

        to: 1.0

        duration: 300
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnimation

        target: root
        property: "reveal"

        to: 0.0

        duration: 200
        easing.type: Easing.InCubic

        onFinished: {
            if (!root.opened)
                root.visible = false
        }
    }

    // ─────────────────────────────────────────────
    // Application filtering
    // ─────────────────────────────────────────────

    ScriptModel {
        id: filteredApps

        values: {
            const query = search.text.trim().toLowerCase()

            let apps = [
                ...DesktopEntries.applications.values
            ]

            if (query !== "") {
                apps = apps.filter(function(app) {
                    const name = app.name
                        ? app.name.toLowerCase()
                        : ""

                    const generic = app.genericName
                        ? app.genericName.toLowerCase()
                        : ""

                    return name.includes(query)
                        || generic.includes(query)
                })
            }

            apps.sort(function(a, b) {
                return a.name.localeCompare(b.name)
            })

            return apps.slice(0, 60)
        }
    }

    // ─────────────────────────────────────────────
    // Main launcher surface
    // ─────────────────────────────────────────────

    Rectangle {
        id: launcherSurface

        width: root.width
        height: root.height

        /*
         * At reveal 0, only a tiny part of the launcher
         * exists in the bottom-right corner.
         *
         * It slides up + left until fully visible.
         */
        x: (1.0 - root.reveal) * (root.width - 36)
        y: (1.0 - root.reveal) * (root.height - 36)

        opacity: root.reveal

        scale: 0.82 + (root.reveal * 0.18)

        transformOrigin: Item.BottomRight

        radius: root.theme.largeRadius + ((1.0 - root.reveal) * 10)

        color: Qt.rgba(
            root.theme.background.r,
            root.theme.background.g,
            root.theme.background.b,
            0.70
        )

        border.color: Qt.rgba(
            root.theme.foreground.r,
            root.theme.foreground.g,
            root.theme.foreground.b,
            0.11
        )

        border.width: 1

        // ─────────────────────────────────────────
        // Glass inner border
        // ─────────────────────────────────────────

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1

            radius: Math.max(
                0,
                parent.radius - 1
            )

            color: "transparent"

            border.color: Qt.rgba(
                1,
                1,
                1,
                0.06
            )

            border.width: 1
        }

        // ─────────────────────────────────────────
        // Search box
        // ─────────────────────────────────────────

        Rectangle {
            id: searchBox

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right

                topMargin: 12
                leftMargin: 12
                rightMargin: 12
            }

            height: 46
            radius: 18

            color: Qt.rgba(
                root.theme.surface.r,
                root.theme.surface.g,
                root.theme.surface.b,
                0.48
            )

            border.color: Qt.rgba(
                1,
                1,
                1,
                0.065
            )

            border.width: 1

            TextInput {
                id: search

                anchors.fill: parent

                anchors.leftMargin: 14
                anchors.rightMargin: 14

                verticalAlignment: TextInput.AlignVCenter

                color: root.theme.foreground

                selectionColor: root.theme.accent
                selectedTextColor: root.theme.background

                font.pixelSize: 14

                clip: true

                onTextChanged: {
                    list.currentIndex = 0
                }

                Keys.onPressed: function(event) {
                    // Escape
                    if (event.key === Qt.Key_Escape) {
                        root.closeLauncher()
                        event.accepted = true
                        return
                    }

                    // Down
                    if (event.key === Qt.Key_Down) {
                        list.currentIndex = Math.min(
                            list.count - 1,
                            list.currentIndex + 1
                        )

                        event.accepted = true
                        return
                    }

                    // Up
                    if (event.key === Qt.Key_Up) {
                        list.currentIndex = Math.max(
                            0,
                            list.currentIndex - 1
                        )

                        event.accepted = true
                        return
                    }

                    // Launch selected application
                    if (
                        event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter
                    ) {
                        const apps = filteredApps.values
                        const appIndex = list.currentIndex

                        if (
                            appIndex >= 0
                            && appIndex < apps.length
                        ) {
                            apps[appIndex].execute()
                            root.closeLauncher()
                        }

                        event.accepted = true
                    }
                }
            }

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 14

                    verticalCenter: parent.verticalCenter
                }

                visible: search.text.length === 0

                text: "Search applications..."

                color: root.theme.mutedForeground

                font.pixelSize: 14
            }
        }

        // ─────────────────────────────────────────
        // Applications
        // ─────────────────────────────────────────

        ListView {
            id: list

            anchors {
                top: searchBox.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right

                topMargin: 8
                bottomMargin: 10
                leftMargin: 8
                rightMargin: 8
            }

            clip: true
            spacing: 4

            model: filteredApps

            delegate: Rectangle {
                id: appDelegate

                required property var modelData

                property var app: modelData

                width: list.width
                height: 52

                radius: 18

                // ONLY highlight on mouse hover.
                color: appMouse.containsMouse
                    ? Qt.rgba(
                        root.theme.surfaceHover.r,
                        root.theme.surfaceHover.g,
                        root.theme.surfaceHover.b,
                        0.65
                    )
                    : "transparent"

                border.color: appMouse.containsMouse
                    ? Qt.rgba(
                        1,
                        1,
                        1,
                        0.05
                    )
                    : "transparent"

                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                // ─────────────────────────────────
                // Icon
                // ─────────────────────────────────

                IconImage {
                    id: appIcon

                    anchors {
                        left: parent.left
                        leftMargin: 10

                        verticalCenter: parent.verticalCenter
                    }

                    implicitSize: 28

                    source: Quickshell.iconPath(
                        appDelegate.app.icon,
                        "application-x-executable"
                    )

                    scale: appMouse.containsMouse
                        ? 1.06
                        : 1.0

                    opacity: appMouse.containsMouse
                        ? 1.0
                        : 0.90

                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 100
                        }
                    }
                }

                // ─────────────────────────────────
                // App text
                // ─────────────────────────────────

                Column {
                    anchors {
                        left: appIcon.right
                        right: parent.right

                        leftMargin: 12
                        rightMargin: 8

                        verticalCenter: parent.verticalCenter
                    }

                    spacing: 2

                    Text {
                        width: parent.width

                        text: appDelegate.app.name

                        color: root.theme.foreground

                        font.pixelSize: 13
                        font.weight: Font.Medium

                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width

                        visible:
                            appDelegate.app.genericName !== ""

                        text:
                            appDelegate.app.genericName

                        color:
                            root.theme.mutedForeground

                        font.pixelSize: 10

                        elide: Text.ElideRight
                    }
                }

                // ─────────────────────────────────
                // Mouse
                // ─────────────────────────────────

                MouseArea {
                    id: appMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onEntered: {
                        list.currentIndex = index
                    }

                    onClicked: {
                        appDelegate.app.execute()
                        root.closeLauncher()
                    }
                }
            }
        }
    }
}