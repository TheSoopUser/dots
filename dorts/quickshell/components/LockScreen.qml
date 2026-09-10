import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

Scope {
    id: root

    required property var theme

    // If you use hyprpaper, this is filled automatically from:
    //     hyprctl hyprpaper listactive
    //
    // If you use a different wallpaper daemon, set this from shell.qml:
    //     wallpaperSource: "file:///home/you/Pictures/wallpaper.png"
    property url wallpaperSource: ""
    property var activeWallpapers: ({})

    property string pamConfig: "login"

    readonly property string username: Quickshell.env("USER") || "user"
    readonly property bool locked: sessionLock.locked

    property string authText: ""
    property string statusText: "Enter your password"
    property bool authFailed: false

    // Shared across all lock surfaces so multi-monitor unlock animation
    // finishes before the compositor session lock is actually released.
    property bool unlocking: false
    property real unlockProgress: 0.0
    property bool lockRequested: false

    signal clearPassword()
    signal focusPassword()

    function glass(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function resetAuthentication() {
        authText = ""
        authFailed = false
        statusText = "Enter your password"
        unlocking = false
        unlockProgress = 0.0
        clearPassword()
    }

    function beginUnlock() {
        if (unlocking)
            return

        unlocking = true
        unlockProgress = 0.0
        unlockAnimation.restart()
    }

    function refreshWallpaper() {
        if (!wallpaperQuery.running)
            wallpaperQuery.running = true
    }

    function activateRequestedLock() {
        if (!lockRequested || sessionLock.locked)
            return

        lockRequested = false
        sessionLock.locked = true
    }

    function parseHyprpaper(text) {
        var next = ({})
        var lines = text.trim().split("\n")

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            var splitAt = line.indexOf(": ")

            if (splitAt <= 0)
                continue

            var monitor = line.substring(0, splitAt).trim()
            var path = line.substring(splitAt + 2).trim()

            if (monitor.length > 0 && path.length > 0)
                next[monitor] = path
        }

        activeWallpapers = next

        for (var monitor in next)
            console.log("LockScreen wallpaper:", monitor, "->", next[monitor])

        // Warm Qt's image cache before the secure surfaces are created.
        // The preloader is synchronous, and callLater gives bindings a turn
        // to update to the newly discovered Hyprpaper path.
        if (lockRequested) {
            Qt.callLater(function() {
                wallpaperPreloader.source = root.wallpaperForScreen("")
                Qt.callLater(root.activateRequestedLock)
            })
        }
    }

    function wallpaperForScreen(screenName) {
        var path = ""

        if (screenName && activeWallpapers[screenName])
            path = activeWallpapers[screenName]

        // Fallback to the first active wallpaper if there is no exact
        // monitor match.
        if (path.length === 0) {
            for (var monitor in activeWallpapers) {
                path = activeWallpapers[monitor]
                break
            }
        }

        if (path.length > 0) {
            if (path.indexOf("file://") === 0)
                return path

            // encodeURI preserves slashes while escaping spaces and other
            // characters that otherwise make Image.source fail silently.
            return "file://" + encodeURI(path)
        }

        return wallpaperSource
    }

    function lock() {
        if (sessionLock.locked || lockRequested)
            return

        if (pam.active)
            pam.abort()

        resetAuthentication()

        // Query Hyprpaper first so the first rendered lock frame already has
        // the correct wallpaper instead of briefly showing the fallback.
        lockRequested = true
        refreshWallpaper()
    }

    function submit(password) {
        if (password.length === 0 || pam.active)
            return

        authText = password
        authFailed = false
        statusText = "Checking password…"

        if (!pam.start()) {
            authText = ""
            authFailed = true
            statusText = "Could not start authentication"
            clearPassword()
            focusPassword()
        }
    }

    function fail(message) {
        authText = ""
        authFailed = true
        statusText = message
        clearPassword()
        focusPassword()
    }

    Component.onCompleted: refreshWallpaper()

    // Invisible synchronous image used only to warm Qt's cache. This prevents
    // the lock surface from painting its fallback background before the
    // wallpaper has been decoded.
    Image {
        id: wallpaperPreloader
        visible: false
        width: 1
        height: 1
        asynchronous: false
        cache: true
        smooth: true
        source: root.wallpaperForScreen("")
    }

    NumberAnimation {
        id: unlockAnimation
        target: root
        property: "unlockProgress"
        from: 0.0
        to: 1.0
        duration: 520
        easing.type: Easing.InOutCubic

        onFinished: {
            if (!root.unlocking)
                return

            // Only release the secure session after the visual transition.
            sessionLock.locked = false
            root.unlocking = false
            root.unlockProgress = 0.0
            root.lockRequested = false
        }
    }

    Process {
        id: wallpaperQuery

        command: ["hyprctl", "hyprpaper", "listactive"]

        stdout: StdioCollector {
            onStreamFinished: root.parseHyprpaper(this.text)
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PamContext {
        id: pam

        user: root.username
        configDirectory: "/etc/pam.d"
        config: root.pamConfig

        onPamMessage: {
            if (pam.messageIsError && pam.message.length > 0)
                root.statusText = pam.message

            if (pam.responseRequired)
                pam.respond(root.authText)
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.authText = ""
                root.authFailed = false
                root.statusText = "Unlocked"
                root.clearPassword()
                root.beginUnlock()
            } else if (result === PamResult.MaxTries) {
                root.fail("Too many attempts — try again")
            } else if (result === PamResult.Error) {
                root.fail("Authentication error")
            } else {
                root.fail("Incorrect password")
            }
        }

        onError: error => {
            console.error("Lock screen PAM error:", error)
            root.fail("Authentication error")
        }
    }

    IpcHandler {
        target: "lockscreen"

        function lock(): void {
            root.lock()
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "lock-screen"
        description: "Lock the session"
        onPressed: root.lock()
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockSurface

            // Keep the secure lock surface opaque. The wallpaper is rendered
            // inside the lock surface instead of exposing the desktop below it.
            color: root.theme.background

            property real introProgress: 0.0
            readonly property url monitorWallpaper:
                root.wallpaperForScreen(screen ? screen.name : "")

            onVisibleChanged: {
                if (visible) {
                    introProgress = 0.0
                    introAnimation.restart()

                    Qt.callLater(function() {
                        passwordInput.forceActiveFocus()
                    })
                }
            }

            SequentialAnimation {
                id: introAnimation

                NumberAnimation {
                    target: lockSurface
                    property: "introProgress"
                    from: 0.0
                    to: 1.0
                    duration: 700
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: root.theme.background
                clip: true

                // Fallback background while the wallpaper is loading.
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.darker(root.theme.surfaceRaised, 1.08)
                    }

                    GradientStop {
                        position: 0.50
                        color: root.theme.background
                    }

                    GradientStop {
                        position: 1.0
                        color: Qt.darker(root.theme.background, 1.20)
                    }
                }

                Image {
                    id: wallpaper

                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height

                    source: lockSurface.monitorWallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: false
                    cache: true
                    smooth: true

                    // Full-strength wallpaper once loaded. The entry starts
                    // slightly dimmed/zoomed, then settles into place.
                    opacity: status === Image.Ready
                        ? (0.72 + (0.28 * lockSurface.introProgress))
                        : 0.0

                    scale: 1.045
                        - (0.045 * lockSurface.introProgress)
                        + (0.035 * root.unlockProgress)

                    transformOrigin: Item.Center

                    onStatusChanged: {
                        if (status === Image.Error)
                            console.warn("LockScreen: failed to load wallpaper:", source)
                    }
                }

                // Keep the wallpaper clearly visible. During unlock the tint
                // fades back even further before the secure surface disappears.
                Rectangle {
                    anchors.fill: parent
                    color: root.glass(
                        root.theme.background,
                        Math.max(
                            0.045,
                            0.24
                                - (0.10 * lockSurface.introProgress)
                                - (0.095 * root.unlockProgress)
                        )
                    )
                }

                // Cool tint over the wallpaper to match the rest of the shell.
                Rectangle {
                    anchors.fill: parent
                    color: root.glass(root.theme.accentStrong, 0.035)
                }

                // Large refractive-looking accent bloom.
                Rectangle {
                    width: Math.min(backdrop.width * 0.62, 900)
                    height: width
                    radius: width / 2
                    x: -Math.min(backdrop.width * 0.62, 900) * 0.35
                    y: -height * 0.42
                    opacity: lockSurface.introProgress * (1.0 - root.unlockProgress)
                    color: root.glass(root.theme.accentStrong, 0.060)

                    SequentialAnimation on x {
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: -Math.min(backdrop.width * 0.62, 900) * 0.35
                            to: -Math.min(backdrop.width * 0.62, 900) * 0.29
                            duration: 9000
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            from: -Math.min(backdrop.width * 0.62, 900) * 0.29
                            to: -Math.min(backdrop.width * 0.62, 900) * 0.35
                            duration: 9000
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Rectangle {
                    width: Math.min(backdrop.width * 0.48, 720)
                    height: width
                    radius: width / 2
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -width * 0.30
                    anchors.bottomMargin: -height * 0.42
                    opacity: lockSurface.introProgress * (1.0 - root.unlockProgress)
                    color: root.glass(root.theme.accent, 0.045)
                }

                // Subtle top sheen.
                Rectangle {
                    width: parent.width * 0.72
                    height: 180
                    radius: height / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -110
                    rotation: -3
                    opacity: 0.45 * lockSurface.introProgress * (1.0 - root.unlockProgress)

                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Qt.rgba(1, 1, 1, 0.075)
                        }

                        GradientStop {
                            position: 1.0
                            color: Qt.rgba(1, 1, 1, 0.0)
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 12
                    radius: root.theme.largeRadius
                    color: "transparent"
                    border.width: 1
                    border.color: root.glass(root.theme.foreground, 0.035)
                    opacity: lockSurface.introProgress * (1.0 - root.unlockProgress)
                }

                Column {
                    id: timeBlock

                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        top: parent.top
                        topMargin: Math.max(58, parent.height * 0.115)
                            - (22 * (1.0 - lockSurface.introProgress))
                            - (26 * root.unlockProgress)
                    }

                    spacing: 2

                    opacity: lockSurface.introProgress
                        * (1.0 - root.unlockProgress)

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "h:mm")
                        color: root.theme.foreground
                        font.pixelSize: Math.max(58,
                            Math.min(92, lockSurface.height * 0.095))
                        font.weight: Font.Light

                        style: Text.Raised
                        styleColor: Qt.rgba(0, 0, 0, 0.20)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
                        color: root.glass(root.theme.foreground, 0.78)
                        font.pixelSize: 15
                        font.weight: Font.Medium
                    }
                }

                Rectangle {
                    id: authCard

                    width: Math.min(430, parent.width - 48)
                    height: 232
                    radius: 32

                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                        verticalCenterOffset:
                            Math.min(132, lockSurface.height * 0.145)
                            + (36 * (1.0 - lockSurface.introProgress))
                            - (24 * root.unlockProgress)
                    }

                    transformOrigin: Item.Center
                    scale: (0.94 + (0.06 * lockSurface.introProgress))
                        * (1.0 + (0.035 * root.unlockProgress))
                    opacity: lockSurface.introProgress
                        * (1.0 - root.unlockProgress)

                    // The visible glass comes from the blurred wallpaper copy
                    // below, so this is intentionally only a faint tint.
                    color: root.glass(root.theme.surface, 0.68)

                    border.width: 1
                    border.color: root.glass(root.theme.foreground, 0.18)

                    // Capture the exact wallpaper region behind this card.
                    // ShaderEffectSource keeps the main wallpaper visible while
                    // providing a texture for MultiEffect to blur.
                    ShaderEffectSource {
                        id: cardGlassSource
                        anchors.fill: parent
                        sourceItem: wallpaper
                        sourceRect: Qt.rect(
                            authCard.x,
                            authCard.y,
                            authCard.width,
                            authCard.height
                        )
                        live: true
                        recursive: false
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: cardGlassSource

                        blurEnabled: true
                        blur: 0.72
                        blurMax: 28
                        blurMultiplier: 1.1

                        saturation: 0.14
                        brightness: 0.035
                        contrast: 0.02

                        autoPaddingEnabled: false

                        maskEnabled: true
                        maskSource: Rectangle {
                            width: authCard.width
                            height: authCard.height
                            radius: authCard.radius
                            visible: false
                        }
                    }

                    // Dark translucent tint above the refracted wallpaper.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: root.glass(root.theme.surface, 0.59)
                    }

                    // Soft blue refraction along the lower edge.
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            margins: 1
                        }

                        height: parent.height * 0.42
                        radius: parent.radius
                        opacity: 0.55

                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(
                                    root.theme.accent.r,
                                    root.theme.accent.g,
                                    root.theme.accent.b,
                                    0.0
                                )
                            }

                            GradientStop {
                                position: 1.0
                                color: root.glass(root.theme.accent, 0.095)
                            }
                        }
                    }

                    // Moving internal highlight gives the card a liquid feel.
                    Rectangle {
                        id: liquidHighlight

                        width: 150
                        height: 310
                        radius: width / 2
                        y: -42
                        rotation: 22
                        color: Qt.rgba(1, 1, 1, 0.050)

                        SequentialAnimation on x {
                            loops: Animation.Infinite

                            NumberAnimation {
                                from: -180
                                to: authCard.width + 30
                                duration: 7200
                                easing.type: Easing.InOutSine
                            }

                            PauseAnimation {
                                duration: 900
                            }

                            NumberAnimation {
                                from: authCard.width + 30
                                to: -180
                                duration: 7200
                                easing.type: Easing.InOutSine
                            }

                            PauseAnimation {
                                duration: 900
                            }
                        }
                    }

                    // Thin bright rim + lower dark rim creates the curved-glass
                    // edge without requiring a custom shader.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Math.max(0, parent.radius - 1)
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.085)
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 18
                            rightMargin: 18
                            bottomMargin: 2
                        }

                        height: 1
                        radius: 1
                        color: root.glass(root.theme.accent, 0.40)
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 13

                        Row {
                            width: parent.width
                            spacing: 12

                            Rectangle {
                                width: 44
                                height: 44
                                radius: height / 2
                                color: root.glass(root.theme.accent, 0.14)
                                border.width: 1
                                border.color: root.glass(root.theme.accent, 0.26)

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: height / 2
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.065)
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.username.length > 0
                                        ? root.username.charAt(0).toUpperCase()
                                        : "U"
                                    color: root.theme.foreground
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: root.username
                                    color: root.theme.foreground
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: "Session locked"
                                    color: root.glass(root.theme.foreground, 0.64)
                                    font.pixelSize: 10
                                }
                            }
                        }

                        Rectangle {
                            id: passwordField

                            width: parent.width
                            height: 48
                            radius: height / 2

                            color: passwordInput.activeFocus
                                ? root.glass(root.theme.surfaceHover, 0.78)
                                : root.glass(root.theme.background, 0.54)

                            border.width: 1
                            border.color: root.authFailed
                                ? root.glass(root.theme.danger, 0.78)
                                : passwordInput.activeFocus
                                    ? root.glass(root.theme.accent, 0.64)
                                    : Qt.rgba(1, 1, 1, 0.105)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 130
                                }
                            }


                            Rectangle {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    leftMargin: 14
                                    rightMargin: 14
                                    topMargin: 1
                                }

                                height: 1
                                color: Qt.rgba(1, 1, 1, 0.060)
                            }

                            Text {
                                visible: passwordInput.text.length === 0
                                text: "Password"
                                color: root.theme.subtleForeground
                                font.pixelSize: 13

                                anchors {
                                    left: parent.left
                                    leftMargin: 18
                                    verticalCenter: parent.verticalCenter
                                }
                            }

                            TextInput {
                                id: passwordInput

                                focus: true
                                enabled: !pam.active && !root.unlocking
                                verticalAlignment: TextInput.AlignVCenter
                                color: root.theme.foreground
                                selectionColor: root.theme.accent
                                selectedTextColor: root.theme.background
                                font.pixelSize: 14
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                clip: true

                                anchors {
                                    left: parent.left
                                    right: submitButton.left
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 18
                                    rightMargin: 10
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Return
                                            || event.key === Qt.Key_Enter) {
                                        root.submit(text)
                                        event.accepted = true
                                    }
                                }
                            }

                            Rectangle {
                                id: submitButton

                                width: 38
                                height: 38
                                radius: height / 2

                                scale: submitMouse.pressed
                                    ? 0.92
                                    : submitMouse.containsMouse
                                        ? 1.04
                                        : 1.0

                                color: passwordInput.text.length > 0
                                    && !pam.active && !root.unlocking
                                    ? root.glass(
                                        root.theme.accent,
                                        submitMouse.containsMouse ? 1.0 : 0.88
                                    )
                                    : root.glass(root.theme.foreground, 0.09)

                                border.width: 1
                                border.color: passwordInput.text.length > 0
                                    && !pam.active
                                    ? Qt.rgba(1, 1, 1, 0.14)
                                    : "transparent"

                                anchors {
                                    right: parent.right
                                    rightMargin: 5
                                    verticalCenter: parent.verticalCenter
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 100
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: pam.active ? "···" : "→"

                                    color: passwordInput.text.length > 0
                                        && !pam.active && !root.unlocking
                                        ? root.theme.background
                                        : root.theme.subtleForeground

                                    font.pixelSize: pam.active ? 10 : 19
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: submitMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: passwordInput.text.length > 0
                                        && !pam.active
                                        && !root.unlocking
                                    onClicked:
                                        root.submit(passwordInput.text)
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.statusText

                            color: root.authFailed
                                ? root.theme.danger
                                : root.glass(root.theme.foreground, 0.68)

                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: "Press Enter to unlock"
                            color: root.glass(root.theme.foreground, 0.44)
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Row {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin:
                            28
                            - (12 * (1.0 - lockSurface.introProgress))
                            - (14 * root.unlockProgress)
                    }

                    spacing: 8
                    opacity: lockSurface.introProgress
                        * (1.0 - root.unlockProgress)

                    Rectangle {
                        width: 7
                        height: 7
                        radius: width / 2

                        color: sessionLock.secure
                            ? root.theme.accent
                            : root.theme.warning
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        text: sessionLock.secure
                            ? "Secure session lock"
                            : "Securing session…"

                        color: root.glass(root.theme.foreground, 0.48)
                        font.pixelSize: 9
                    }
                }

                Connections {
                    target: root

                    function onClearPassword() {
                        passwordInput.text = ""
                    }

                    function onFocusPassword() {
                        Qt.callLater(function() {
                            passwordInput.forceActiveFocus()
                        })
                    }
                }
            }
        }
    }
}
