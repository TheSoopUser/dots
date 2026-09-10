import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var theme

    // Put wallpapers here, or change this path.
    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string activeWallpapers: ""
    property bool opened: false
    property real reveal: 0.0

    // Liquid-glass wallpaper switch transition
    property bool switching: false
    property string pendingWallpaper: ""
    property real liquidOpacity: 0.0
    property real liquidScale: 1.04
    property real liquidInnerOpacity: 0.0
    property real liquidSheenOpacity: 0.0
    property real liquidLabelOpacity: 0.0
    property real liquidRippleScale: 0.88

    WlrLayershell.namespace: "quickshell-wallpaper-switcher"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: true

    color: "transparent"
    surfaceFormat.opaque: false
    visible: false

    function glass(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function refresh() {
        if (!scanner.running) {
            scanner.exec([
                "find",
                root.wallpaperDir,
                "-maxdepth", "1",
                "-type", "f",
                "(",
                    "-iname", "*.png",
                    "-o", "-iname", "*.jpg",
                    "-o", "-iname", "*.jpeg",
                    "-o", "-iname", "*.webp",
                    "-o", "-iname", "*.jxl",
                ")",
                "-print"
            ])
        }

        if (!activeProc.running)
            activeProc.exec(["hyprctl", "hyprpaper", "listactive"])
    }

    function openSwitcher() {
        if (root.switching)
            return

        closeAnimation.stop()
        root.opened = true

        if (!root.visible) {
            root.reveal = 0.0
            root.visible = true
        }

        root.refresh()
        openAnimation.restart()

        Qt.callLater(function() {
            keyHandler.forceActiveFocus()
        })
    }

    function closeSwitcher() {
        if (!root.visible)
            return

        openAnimation.stop()
        root.opened = false
        closeAnimation.restart()
    }

    function toggle() {
        if (root.opened)
            root.closeSwitcher()
        else
            root.openSwitcher()
    }

    function beginWallpaperTransition(path) {
        if (path === "" || root.switching || wallpaperSetter.running)
            return

        root.pendingWallpaper = path
        root.switching = true
        root.opened = false

        openAnimation.stop()
        closeAnimation.restart()

        if (!root.visible)
            root.visible = true

        root.liquidOpacity = 0.0
        root.liquidScale = 1.04
        root.liquidInnerOpacity = 0.0
        root.liquidSheenOpacity = 0.0
        root.liquidLabelOpacity = 0.0
        root.liquidRippleScale = 0.88

        liquidIn.restart()
        liquidInnerIn.restart()
        liquidSheenIn.restart()
        liquidLabelIn.restart()
        liquidRippleIn.restart()
        applyWallpaperTimer.restart()
    }

    function setWallpaper(path) {
        beginWallpaperTransition(path)
    }

    function finishWallpaperTransition() {
        liquidOut.restart()
        liquidInnerOut.restart()
        liquidSheenOut.restart()
        liquidLabelOut.restart()
        liquidRippleOut.restart()
    }

    NumberAnimation {
        id: openAnimation
        target: root
        property: "reveal"
        from: root.reveal
        to: 1.0
        duration: 240
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnimation
        target: root
        property: "reveal"
        from: root.reveal
        to: 0.0
        duration: 170
        easing.type: Easing.InCubic

        onFinished: {
            if (!root.opened && !root.switching)
                root.visible = false
        }
    }

    ParallelAnimation {
        id: liquidIn

        NumberAnimation {
            target: root
            property: "liquidOpacity"
            from: 0.0
            to: 1.0
            duration: 230
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "liquidScale"
            from: 1.04
            to: 1.0
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: liquidOut

        NumberAnimation {
            target: root
            property: "liquidOpacity"
            from: root.liquidOpacity
            to: 0.0
            duration: 300
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: root
            property: "liquidScale"
            from: root.liquidScale
            to: 0.985
            duration: 300
            easing.type: Easing.InOutCubic
        }

        onFinished: {
            root.switching = false
            root.pendingWallpaper = ""
            root.liquidScale = 1.04
            root.liquidRippleScale = 0.88

            if (!root.opened)
                root.visible = false
        }
    }

    NumberAnimation {
        id: liquidInnerIn
        target: root
        property: "liquidInnerOpacity"
        from: 0.0
        to: 1.0
        duration: 260
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: liquidInnerOut
        target: root
        property: "liquidInnerOpacity"
        from: root.liquidInnerOpacity
        to: 0.0
        duration: 240
        easing.type: Easing.InOutCubic
    }

    NumberAnimation {
        id: liquidSheenIn
        target: root
        property: "liquidSheenOpacity"
        from: 0.0
        to: 1.0
        duration: 220
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: liquidSheenOut
        target: root
        property: "liquidSheenOpacity"
        from: root.liquidSheenOpacity
        to: 0.0
        duration: 220
        easing.type: Easing.InCubic
    }

    NumberAnimation {
        id: liquidLabelIn
        target: root
        property: "liquidLabelOpacity"
        from: 0.0
        to: 1.0
        duration: 180
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: liquidLabelOut
        target: root
        property: "liquidLabelOpacity"
        from: root.liquidLabelOpacity
        to: 0.0
        duration: 160
        easing.type: Easing.InCubic
    }

    NumberAnimation {
        id: liquidRippleIn
        target: root
        property: "liquidRippleScale"
        from: 0.88
        to: 1.06
        duration: 420
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: liquidRippleOut
        target: root
        property: "liquidRippleScale"
        from: root.liquidRippleScale
        to: 1.12
        duration: 260
        easing.type: Easing.InCubic
    }

    SequentialAnimation {
        id: sheenSweep
        running: root.switching
        loops: Animation.Infinite

        NumberAnimation {
            target: sheenBand
            property: "x"
            from: -sheenBand.width
            to: liquidGlass.width
            duration: 900
            easing.type: Easing.InOutQuad
        }

        PauseAnimation { duration: 110 }
    }

    Timer {
        id: applyWallpaperTimer
        interval: 130
        onTriggered: {
            wallpaperSetter.exec([
                "sh",
                "-c",
                "wp=\"$1\"; " +
                "hyprctl monitors | awk '/^Monitor / {print $2}' | " +
                "while IFS= read -r mon; do " +
                    "hyprctl hyprpaper wallpaper \"$mon, $wp, cover\" >/dev/null; " +
                "done",
                "quickshell-wallpaper",
                root.pendingWallpaper
            ])

            root.activeWallpapers = root.pendingWallpaper
        }
    }

    Timer {
        id: switchHoldTimer
        interval: 160
        onTriggered: root.finishWallpaperTransition()
    }

    ListModel {
        id: wallpaperModel
    }

    Process {
        id: scanner

        stdout: StdioCollector {
            onStreamFinished: {
                wallpaperModel.clear()

                const files = text
                    .split("\n")
                    .filter(function(path) { return path.length > 0 })
                    .sort(function(a, b) { return a.localeCompare(b) })

                for (let i = 0; i < files.length; ++i) {
                    const file = files[i]
                    wallpaperModel.append({
                        wallpaperPath: file,
                        wallpaperName: file.substring(file.lastIndexOf("/") + 1)
                    })
                }
            }
        }
    }

    Process {
        id: activeProc

        stdout: StdioCollector {
            onStreamFinished: root.activeWallpapers = text
        }
    }

    Process {
        id: wallpaperSetter

        onRunningChanged: {
            if (!running) {
                if (root.visible)
                    activeProc.exec(["hyprctl", "hyprpaper", "listactive"])

                if (root.switching)
                    switchHoldTimer.restart()
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void { root.toggle() }
        function open(): void { root.openSwitcher() }
        function close(): void { root.closeSwitcher() }
        function refresh(): void { root.refresh() }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.44 * root.reveal)

        MouseArea {
            anchors.fill: parent
            enabled: root.opened
            onClicked: root.closeSwitcher()
        }
    }

    // Full-screen liquid-glass transition overlay without previewing the next wallpaper.
    Item {
        anchors.fill: parent
        visible: root.switching || root.liquidOpacity > 0.0
        z: 20

        Rectangle {
            id: liquidGlass
            anchors.fill: parent
            opacity: root.liquidOpacity
            scale: root.liquidScale
            color: root.glass(root.theme.background, 0.18)
        }

        Rectangle {
            anchors.fill: parent
            opacity: 0.30 * root.liquidInnerOpacity
            color: root.glass(root.theme.surfaceRaised, 0.80)
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * root.liquidRippleScale
            height: parent.height * root.liquidRippleScale
            radius: Math.min(width, height) * 0.08
            opacity: 0.17 * root.liquidInnerOpacity
            color: root.glass(root.theme.accent, 0.34)
            border.width: 1
            border.color: root.glass(root.theme.foreground, 0.12)
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * (root.liquidRippleScale * 0.82)
            height: parent.height * (root.liquidRippleScale * 0.82)
            radius: Math.min(width, height) * 0.08
            opacity: 0.13 * root.liquidInnerOpacity
            color: root.glass(root.theme.surface, 0.42)
            border.width: 1
            border.color: root.glass(root.theme.foreground, 0.08)
        }

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: parent.height * 0.35
            opacity: 0.12 * root.liquidSheenOpacity
            color: root.glass(Qt.tint(root.theme.foreground, root.theme.accent), 0.65)
        }

        Rectangle {
            id: sheenBand
            width: parent.width * 0.38
            height: parent.height * 1.35
            y: -parent.height * 0.12
            rotation: -16
            opacity: 0.16 * root.liquidSheenOpacity
            visible: root.switching || root.liquidSheenOpacity > 0.0
            color: root.glass(root.theme.foreground, 0.95)
        }

        Rectangle {
            width: 232
            height: 46
            radius: 23
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 42
            }
            color: root.glass(root.theme.background, 0.78)
            border.width: 1
            border.color: root.glass(root.theme.foreground, 0.10)
            opacity: root.liquidLabelOpacity

            Text {
                anchors.centerIn: parent
                text: "Switching wallpaper..."
                color: root.theme.foreground
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: if (!root.switching) root.closeSwitcher()
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent
        width: Math.min(1040, root.width - 72)
        height: Math.min(680, root.height - 88)
        radius: root.theme.largeRadius
        clip: true

        opacity: root.reveal
        scale: 0.94 + (0.06 * root.reveal)
        y: ((root.height - height) / 2) + ((1.0 - root.reveal) * 22)

        color: root.glass(root.theme.background, 0.82)
        border.width: 1
        border.color: root.glass(root.theme.foreground, 0.13)

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: root.glass(root.theme.foreground, 0.035)
        }

        // Prevent clicks inside the panel from closing the switcher.
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 92
            color: root.glass(root.theme.surfaceRaised, 0.24)

            Text {
                id: title
                anchors {
                    left: parent.left
                    top: parent.top
                    leftMargin: 28
                    topMargin: 20
                }
                text: "Wallpapers"
                color: root.theme.foreground
                font.pixelSize: 23
                font.weight: Font.DemiBold
            }

            Text {
                anchors {
                    left: title.left
                    top: title.bottom
                    topMargin: 4
                }
                text: root.wallpaperDir
                color: root.theme.mutedForeground
                font.pixelSize: 10
                elide: Text.ElideMiddle
                width: Math.min(620, header.width - 190)
            }

            Rectangle {
                id: refreshButton
                anchors {
                    right: closeButton.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 38
                height: 38
                radius: height / 2
                scale: refreshMouse.pressed ? 0.94 : refreshMouse.containsMouse ? 1.04 : 1.0
                color: refreshMouse.containsMouse
                    ? root.glass(root.theme.surfaceHover, 0.82)
                    : root.glass(root.theme.surface, 0.48)
                border.width: 1
                border.color: root.glass(root.theme.foreground, 0.07)

                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    color: root.theme.foreground
                    font.pixelSize: 19
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.refresh()
                }
            }

            Rectangle {
                id: closeButton
                anchors {
                    right: parent.right
                    rightMargin: 22
                    verticalCenter: parent.verticalCenter
                }
                width: 38
                height: 38
                radius: height / 2
                scale: closeMouse.pressed ? 0.94 : closeMouse.containsMouse ? 1.04 : 1.0
                color: closeMouse.containsMouse
                    ? root.glass(root.theme.surfaceHover, 0.82)
                    : root.glass(root.theme.surface, 0.48)
                border.width: 1
                border.color: root.glass(root.theme.foreground, 0.07)

                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: root.theme.mutedForeground
                    font.pixelSize: 22
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.closeSwitcher()
                }
            }
        }

        GridView {
            id: grid

            anchors {
                top: header.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: 18
                topMargin: 16
            }

            clip: true
            model: wallpaperModel
            boundsBehavior: Flickable.StopAtBounds

            cellWidth: 250
            cellHeight: 168

            delegate: Item {
                id: delegateRoot

                required property string wallpaperPath
                required property string wallpaperName

                property bool selected: root.activeWallpapers.indexOf(wallpaperPath) !== -1

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 7
                    radius: 18
                    clip: true

                    scale: cardMouse.pressed ? 0.97 : cardMouse.containsMouse ? 1.018 : 1.0
                    color: root.glass(root.theme.surface, 0.58)
                    border.width: delegateRoot.selected ? 2 : 1
                    border.color: delegateRoot.selected
                        ? root.glass(root.theme.accent, 0.92)
                        : cardMouse.containsMouse
                            ? root.glass(root.theme.foreground, 0.18)
                            : root.glass(root.theme.foreground, 0.07)

                    Behavior on scale {
                        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: 120 }
                    }

                    Image {
                        anchors.fill: parent
                        source: "file://" + delegateRoot.wallpaperPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 44
                        color: root.glass(root.theme.background, 0.78)
                    }

                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 13
                            rightMargin: 13
                            bottomMargin: 13
                        }
                        text: delegateRoot.wallpaperName
                        color: root.theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        visible: delegateRoot.selected
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: 10
                            rightMargin: 10
                        }
                        width: 25
                        height: 25
                        radius: height / 2
                        color: root.theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: root.theme.background
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.switching
                        onClicked: root.setWallpaper(delegateRoot.wallpaperPath)
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: wallpaperModel.count === 0 && !scanner.running

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No wallpapers found"
                color: root.theme.foreground
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Add images to " + root.wallpaperDir
                color: root.theme.mutedForeground
                font.pixelSize: 10
            }
        }
    }
}
