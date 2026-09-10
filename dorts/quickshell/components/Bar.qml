import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var theme
    required property var audio
    required property var brightness
    required property var network
    required property var notifications
    required property var lockScreen

    WlrLayershell.namespace: "quickshell-shell"

    property int workspaceCount: 5
    property color barIconColor: "#c9c9c9"

    component BarIcon: Item {
        property string source: ""
        property real iconSize: 15

        implicitWidth: iconSize
        implicitHeight: iconSize

        IconImage {
            id: sourceIcon
            anchors.fill: parent
            source: parent.source
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: sourceIcon
            colorization: 1.0
            colorizationColor: root.barIconColor
        }
    }

    property bool expanded: barHover.hovered
        || launcher.visible
        || notificationCenter.visible
        || statsPopup.visible
        || sidePanel.opened

    property real collapsedWidth: clockPill.width + 12
    property real expandedWidth: width - 12

    property string networkIcon: root.network.connected
        ? "network-wireless-signal-excellent-symbolic"
        : "network-offline-symbolic"

    property string volumeIcon: {
        if (root.audio.muted || root.audio.volumePercent === 0)
            return "audio-volume-muted-symbolic"
        if (root.audio.volumePercent < 35)
            return "audio-volume-low-symbolic"
        if (root.audio.volumePercent < 70)
            return "audio-volume-medium-symbolic"
        return "audio-volume-high-symbolic"
    }

    // Lightweight bar statistics.
    property int cpuPercent: 0
    property int memoryPercent: 0
    property real downloadBps: 0
    property real uploadBps: 0

    property real _previousCpuTotal: 0
    property real _previousCpuIdle: 0
    property real _previousRx: -1
    property real _previousTx: -1
    property real _previousNetworkTime: 0

    // Detailed popup statistics.
    property string cpuModel: "Unknown CPU"
    property string loadAverage: "0.00 0.00 0.00"
    property int logicalCores: 0
    property string topCpuProcess: "—"

    property real memTotalKb: 0
    property real memAvailableKb: 0
    property real memCachedKb: 0
    property real swapTotalKb: 0
    property real swapFreeKb: 0

    property string detailInterface: "—"
    property string detailIpv4: "—"
    property real detailRxBytes: 0
    property real detailTxBytes: 0

    function glass(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    function switchWorkspace(number) {
        if (Hyprland.usingLua)
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + number + '" })')
        else
            Hyprland.dispatch("workspace " + number)
    }

    function formatRate(bytes) {
        if (bytes < 1024)
            return Math.round(bytes) + " B/s"
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + "K"
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / 1024 / 1024).toFixed(1) + "M"
        return (bytes / 1024 / 1024 / 1024).toFixed(1) + "G"
    }

    function formatBytes(bytes) {
        const value = Number(bytes) || 0

        if (value < 1024)
            return Math.round(value) + " B"
        if (value < 1024 * 1024)
            return (value / 1024).toFixed(1) + " KiB"
        if (value < 1024 * 1024 * 1024)
            return (value / 1024 / 1024).toFixed(1) + " MiB"
        if (value < 1024 * 1024 * 1024 * 1024)
            return (value / 1024 / 1024 / 1024).toFixed(1) + " GiB"
        return (value / 1024 / 1024 / 1024 / 1024).toFixed(1) + " TiB"
    }

    function formatMemory(kb) {
        return formatBytes(kb * 1024)
    }

    function updateSystemStats(output) {
        const values = output.trim().split(/\s+/)
        if (values.length < 6)
            return

        const cpuTotal = Number(values[0])
        const cpuIdle = Number(values[1])
        const memTotal = Number(values[2])
        const memAvailable = Number(values[3])
        const rx = Number(values[4])
        const tx = Number(values[5])

        if (_previousCpuTotal > 0) {
            const totalDelta = cpuTotal - _previousCpuTotal
            const idleDelta = cpuIdle - _previousCpuIdle

            if (totalDelta > 0) {
                cpuPercent = Math.round((1 - idleDelta / totalDelta) * 100)
                cpuPercent = Math.max(0, Math.min(100, cpuPercent))
            }
        }

        _previousCpuTotal = cpuTotal
        _previousCpuIdle = cpuIdle

        if (memTotal > 0)
            memoryPercent = Math.round(((memTotal - memAvailable) / memTotal) * 100)

        const now = Date.now()
        if (_previousRx >= 0 && _previousTx >= 0 && _previousNetworkTime > 0) {
            const seconds = (now - _previousNetworkTime) / 1000

            if (seconds > 0) {
                downloadBps = Math.max(0, (rx - _previousRx) / seconds)
                uploadBps = Math.max(0, (tx - _previousTx) / seconds)
            }
        }

        _previousRx = rx
        _previousTx = tx
        _previousNetworkTime = now
    }

    function updateDetailedStats(output) {
        const values = output.trim().split("|")
        if (values.length < 13)
            return

        loadAverage = values[0]
        logicalCores = Number(values[1]) || 0
        cpuModel = values[2] || "Unknown CPU"
        topCpuProcess = values[3] || "—"

        memTotalKb = Number(values[4]) || 0
        memAvailableKb = Number(values[5]) || 0
        memCachedKb = Number(values[6]) || 0
        swapTotalKb = Number(values[7]) || 0
        swapFreeKb = Number(values[8]) || 0

        detailInterface = values[9] || "—"
        detailIpv4 = values[10] || "—"
        detailRxBytes = Number(values[11]) || 0
        detailTxBytes = Number(values[12]) || 0
    }

    anchors {
        top: true
        left: true
        right: true
    }

    height: theme.barHeight + 8
    exclusiveZone: height
    color: "transparent"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: systemStatsProcess

        command: [
            "sh",
            "-c",
            "cpu=$(awk 'NR==1 { idle=$5+$6; total=0; for(i=2;i<=9;i++) total+=$i; print total, idle }' /proc/stat); "
            + "mem=$(awk '/^MemTotal:/ { total=$2 } /^MemAvailable:/ { avail=$2 } END { print total, avail }' /proc/meminfo); "
            + "iface=$(awk '$2 == \"00000000\" { print $1; exit }' /proc/net/route); "
            + "rx=0; tx=0; "
            + "if [ -n \"$iface\" ]; then "
            + "net=$(awk -v iface=\"$iface\" '$1 == iface \":\" { print $2, $10 }' /proc/net/dev); "
            + "set -- $net; rx=${1:-0}; tx=${2:-0}; fi; "
            + "printf '%s %s %s %s\\n' \"$cpu\" \"$mem\" \"$rx\" \"$tx\""
        ]

        stdout: StdioCollector {
            onStreamFinished: root.updateSystemStats(text)
        }
    }

    Timer {
        id: systemStatsTimer
        interval: 1000
        repeat: true
        running: true

        onTriggered: {
            if (!systemStatsProcess.running)
                systemStatsProcess.running = true
        }
    }

    Process {
        id: detailedStatsProcess

        command: [
            "sh",
            "-c",
            "load=$(cut -d' ' -f1-3 /proc/loadavg); "
            + "cores=$(nproc); "
            + "model=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo); "
            + "top=$(ps -eo comm=,%cpu= --sort=-%cpu | head -n1 | sed 's/^[[:space:]]*//'); "
            + "mem=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} /^Cached:/ {c=$2} /^SwapTotal:/ {st=$2} /^SwapFree:/ {sf=$2} END {print t \"|\" a \"|\" c \"|\" st \"|\" sf}' /proc/meminfo); "
            + "iface=$(awk '$2 == \"00000000\" {print $1; exit}' /proc/net/route); "
            + "ipaddr=$(ip -4 -o addr show dev \"$iface\" scope global 2>/dev/null | awk 'NR==1 {split($4,a,\"/\"); print a[1]}'); "
            + "rx=$(cat \"/sys/class/net/$iface/statistics/rx_bytes\" 2>/dev/null || echo 0); "
            + "tx=$(cat \"/sys/class/net/$iface/statistics/tx_bytes\" 2>/dev/null || echo 0); "
            + "printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$load\" \"$cores\" \"$model\" \"$top\" \"$mem\" \"$iface\" \"${ipaddr:---}\" \"$rx\" \"$tx\""
        ]

        stdout: StdioCollector {
            onStreamFinished: root.updateDetailedStats(text)
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: statsPopup.visible

        onTriggered: {
            if (!detailedStatsProcess.running)
                detailedStatsProcess.running = true
        }
    }

    Rectangle {
        id: barSurface

        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 6
        }

        width: root.expanded ? root.expandedWidth : root.collapsedWidth
        height: root.theme.barHeight
        radius: Math.min(root.theme.largeRadius, height / 2)
        clip: true

        color: root.glass(root.theme.background, 0.68)
        border.color: root.glass(root.theme.foreground, 0.12)
        border.width: 1

        Behavior on width {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: barHover
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.color: root.glass(root.theme.foreground, 0.045)
            border.width: 1
        }

        Row {
            id: leftSection

            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }

            spacing: 5
            opacity: root.expanded ? 1 : 0
            enabled: root.expanded

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            Rectangle {
                id: launcherButton

                property bool active: launcher.visible

                width: 32
                height: 28
                radius: height / 2
                scale: launcherMouse.pressed ? 0.92 : launcherMouse.containsMouse ? 1.05 : 1.0

                color: active
                    ? root.glass(root.theme.accent, 0.28)
                    : launcherMouse.containsMouse
                        ? root.glass(root.theme.surfaceHover, 0.80)
                        : root.glass(root.theme.surface, 0.52)

                border.color: active
                    ? root.glass(root.theme.accent, 0.55)
                    : root.glass(root.theme.foreground, 0.055)
                border.width: 1

                Behavior on scale {
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                BarIcon {
                    anchors.centerIn: parent
                    iconSize: 16
                    source: Quickshell.iconPath("view-app-grid-symbolic", "applications-system-symbolic")
                    opacity: parent.active || launcherMouse.containsMouse ? 1.0 : 0.82
                }

                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: launcher.toggle()
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: root.workspaceCount

                    delegate: Rectangle {
                        required property int index

                        property int workspaceNumber: index + 1
                        property bool active: Hyprland.focusedWorkspace
                            && Hyprland.focusedWorkspace.id === workspaceNumber

                        width: active ? 34 : 25
                        height: 25
                        radius: 12
                        scale: workspaceMouse.pressed ? 0.92 : workspaceMouse.containsMouse ? 1.04 : 1.0

                        color: active
                            ? root.glass(root.theme.accent, 0.95)
                            : workspaceMouse.containsMouse
                                ? root.glass(root.theme.surfaceHover, 0.72)
                                : "transparent"

                        border.color: active
                            ? "transparent"
                            : workspaceMouse.containsMouse
                                ? root.glass(root.theme.foreground, 0.07)
                                : "transparent"
                        border.width: 1

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
                            text: workspaceNumber
                            color: active ? root.theme.background : root.theme.mutedForeground
                            font.pixelSize: 11
                            font.weight: active ? Font.DemiBold : Font.Medium
                        }

                        MouseArea {
                            id: workspaceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.switchWorkspace(parent.workspaceNumber)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: clockPill

            anchors.centerIn: parent
            height: 28
            width: clockRow.implicitWidth + 20
            radius: height / 2
            scale: clockMouse.pressed ? 0.97 : clockMouse.containsMouse ? 1.02 : 1.0

            color: clockMouse.containsMouse
                ? root.glass(root.theme.surfaceHover, 0.72)
                : root.glass(root.theme.surface, 0.38)

            border.color: root.glass(root.theme.foreground, 0.045)
            border.width: 1

            Behavior on width {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Behavior on scale {
                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 7

                BarIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    iconSize: 14
                    source: Quickshell.iconPath("preferences-system-time-symbolic", "appointment-soon-symbolic")
                    opacity: 0.82
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: clockMouse.containsMouse || root.expanded
                        ? Qt.formatDateTime(clock.date, "ddd, MMM d  •  h:mm AP")
                        : Qt.formatDateTime(clock.date, "h:mm AP")
                    color: root.theme.foreground
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: sidePanel.toggle()
            }
        }

        Row {
            id: rightSection

            anchors {
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }

            spacing: 5
            opacity: root.expanded ? 1 : 0
            enabled: root.expanded

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            // Connected network name.
            Rectangle {
                id: networkPill

                height: 28
                width: networkRow.implicitWidth + 18
                radius: height / 2
                scale: networkMouse.containsMouse ? 1.02 : 1.0

                color: networkMouse.containsMouse
                    ? root.glass(root.theme.surfaceHover, 0.72)
                    : "transparent"

                Behavior on scale {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    id: networkRow
                    anchors.centerIn: parent
                    spacing: 6

                    BarIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 15
                        source: Quickshell.iconPath(root.networkIcon, "network-offline-symbolic")
                        opacity: root.network.connected ? 0.95 : 0.5
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.network.name
                        color: root.network.connected ? root.theme.foreground : root.theme.mutedForeground
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                MouseArea {
                    id: networkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            // CPU / RAM / network throughput. Clicking anywhere opens the detail panel.
            Rectangle {
                id: statsPill

                height: 28
                width: statsRow.implicitWidth + 18
                radius: height / 2
                scale: statsMouse.pressed ? 0.97 : statsMouse.containsMouse ? 1.02 : 1.0

                color: statsPopup.visible
                    ? root.glass(root.theme.accent, 0.22)
                    : statsMouse.containsMouse
                        ? root.glass(root.theme.surfaceHover, 0.76)
                        : root.glass(root.theme.surface, 0.20)

                border.color: statsPopup.visible
                    ? root.glass(root.theme.accent, 0.55)
                    : statsMouse.containsMouse
                        ? root.glass(root.theme.foreground, 0.07)
                        : "transparent"
                border.width: 1

                Behavior on scale {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    id: statsRow
                    anchors.centerIn: parent
                    spacing: 7

                    BarIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 15
                        source: Quickshell.iconPath("utilities-system-monitor-symbolic", "computer-symbolic")
                        opacity: statsMouse.containsMouse || statsPopup.visible ? 1.0 : 0.82
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CPU " + root.cpuPercent + "%"
                        color: root.cpuPercent >= 85
                            ? "#f38ba8"
                            : root.cpuPercent >= 65
                                ? "#fab387"
                                : root.theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 13
                        color: root.glass(root.theme.foreground, 0.09)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RAM " + root.memoryPercent + "%"
                        color: root.memoryPercent >= 85
                            ? "#f38ba8"
                            : root.memoryPercent >= 65
                                ? "#fab387"
                                : root.theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 13
                        color: root.glass(root.theme.foreground, 0.09)
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "↓"
                            color: root.barIconColor
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        Text {
                            text: root.formatRate(root.downloadBps)
                            color: root.theme.mutedForeground
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "↑"
                            color: root.barIconColor
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        Text {
                            text: root.formatRate(root.uploadBps)
                            color: root.theme.mutedForeground
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                MouseArea {
                    id: statsMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        statsPopup.visible = !statsPopup.visible

                        if (statsPopup.visible && !detailedStatsProcess.running)
                            detailedStatsProcess.running = true
                    }
                }
            }

            Rectangle {
                id: volumePill

                height: 28
                width: volumeRow.implicitWidth + 18
                radius: height / 2
                scale: volumeMouse.pressed ? 0.94 : volumeMouse.containsMouse ? 1.03 : 1.0

                color: volumeMouse.containsMouse
                    ? root.glass(root.theme.surfaceHover, 0.76)
                    : "transparent"

                Behavior on scale {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    id: volumeRow
                    anchors.centerIn: parent
                    spacing: 6

                    BarIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 15
                        source: Quickshell.iconPath(root.volumeIcon, "audio-volume-muted-symbolic")
                        opacity: root.audio.muted ? 0.5 : 0.95
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.audio.muted ? "Muted" : root.audio.volumePercent + "%"
                        color: root.audio.muted ? root.theme.mutedForeground : root.theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: volumeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.audio.toggleMute()

                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0)
                            root.audio.changeVolume(0.05)
                        else if (wheel.angleDelta.y < 0)
                            root.audio.changeVolume(-0.05)
                    }
                }
            }

            Rectangle {
                id: brightnessPill

                height: 28
                width: brightnessRow.implicitWidth + 18
                radius: height / 2
                scale: brightnessMouse.containsMouse ? 1.03 : 1.0

                color: brightnessMouse.containsMouse
                    ? root.glass(root.theme.surfaceHover, 0.76)
                    : "transparent"

                Behavior on scale {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    id: brightnessRow
                    anchors.centerIn: parent
                    spacing: 6

                    BarIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 15
                        source: Quickshell.iconPath("display-brightness-symbolic", "weather-clear-symbolic")
                        opacity: 0.95
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.brightness.percent + "%"
                        color: root.theme.foreground
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: brightnessMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0)
                            root.brightness.change(true)
                        else if (wheel.angleDelta.y < 0)
                            root.brightness.change(false)
                    }
                }
            }

            Rectangle {
                id: lockButton

                width: 32
                height: 28
                radius: height / 2
                scale: lockMouse.pressed ? 0.92 : lockMouse.containsMouse ? 1.05 : 1.0

                color: lockMouse.containsMouse
                    ? root.glass(root.theme.surfaceHover, 0.78)
                    : root.glass(root.theme.surface, 0.30)

                border.width: 1
                border.color: lockMouse.containsMouse
                    ? root.glass(root.theme.foreground, 0.08)
                    : "transparent"

                Behavior on scale {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                BarIcon {
                    anchors.centerIn: parent
                    iconSize: 15
                    source: Quickshell.iconPath(
                        "system-lock-screen-symbolic",
                        "changes-prevent-symbolic"
                    )
                    opacity: 0.95
                }

                MouseArea {
                    id: lockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.lockScreen.lock()
                }
            }

            Rectangle {
                id: notificationButton

                property bool active: notificationCenter.visible

                width: root.notifications.count > 0 ? 43 : 32
                height: 28
                radius: height / 2
                scale: notificationMouse.pressed ? 0.92 : notificationMouse.containsMouse ? 1.05 : 1.0

                color: active
                    ? root.glass(root.theme.accent, 0.25)
                    : notificationMouse.containsMouse
                        ? root.glass(root.theme.surfaceHover, 0.78)
                        : root.glass(root.theme.surface, 0.30)

                border.color: active ? root.glass(root.theme.accent, 0.50) : "transparent"
                border.width: 1

                Behavior on width {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    BarIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 15
                        source: Quickshell.iconPath(
                            root.notifications.count > 0
                                ? "notification-active-symbolic"
                                : "notifications-symbolic",
                            "preferences-system-notifications-symbolic"
                        )
                        opacity: 0.95
                    }

                    Text {
                        visible: root.notifications.count > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.notifications.count
                        color: root.theme.accent
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: notificationMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: notificationCenter.visible = !notificationCenter.visible
                }
            }
        }
    }

    PopupWindow {
        id: statsPopup

        anchor {
            item: statsPill
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: 8
        }

        width: 430
        height: 356
        visible: false
        color: "transparent"
        grabFocus: false

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root.glass(root.theme.background, 0.94)
            border.color: root.glass(root.theme.foreground, 0.10)
            border.width: 1

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, parent.radius - 1)
                color: "transparent"
                border.color: root.glass(root.theme.foreground, 0.04)
                border.width: 1
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9

                Item {
                    width: parent.width
                    height: 24

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 17
                            source: Quickshell.iconPath("utilities-system-monitor-symbolic", "computer-symbolic")
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "System Monitor"
                            color: root.theme.foreground
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 23
                        height: 23
                        radius: 11

                        color: closeStatsMouse.containsMouse
                            ? root.glass(root.theme.surfaceHover, 0.8)
                            : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: root.theme.mutedForeground
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: closeStatsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: statsPopup.visible = false
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 88
                    radius: 16
                    color: root.glass(root.theme.surface, 0.42)

                    Text {
                        anchors {
                            top: parent.top
                            left: parent.left
                            topMargin: 9
                            leftMargin: 11
                        }

                        text: "CPU"
                        color: root.theme.foreground
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: 9
                            rightMargin: 11
                        }

                        text: root.cpuPercent + "%"
                        color: root.cpuPercent >= 85
                            ? "#f38ba8"
                            : root.cpuPercent >= 65
                                ? "#fab387"
                                : root.theme.accent
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 11
                            rightMargin: 11
                            topMargin: 30
                        }

                        height: 3
                        radius: height / 2
                        color: root.glass(root.theme.foreground, 0.07)

                        Rectangle {
                            width: parent.width * root.cpuPercent / 100
                            height: parent.height
                            radius: parent.radius
                            color: root.theme.accent

                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 11
                            rightMargin: 11
                            topMargin: 41
                        }

                        text: root.cpuModel
                        color: root.theme.mutedForeground
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                            leftMargin: 11
                            bottomMargin: 8
                        }

                        text: "Load  " + root.loadAverage + "  •  " + root.logicalCores + " threads"
                        color: root.theme.mutedForeground
                        font.pixelSize: 9
                    }

                    Text {
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            rightMargin: 11
                            bottomMargin: 8
                        }

                        text: "Top  " + root.topCpuProcess
                        color: root.theme.mutedForeground
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 88
                    radius: 16
                    color: root.glass(root.theme.surface, 0.42)

                    Text {
                        anchors {
                            top: parent.top
                            left: parent.left
                            topMargin: 9
                            leftMargin: 11
                        }

                        text: "Memory"
                        color: root.theme.foreground
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: 9
                            rightMargin: 11
                        }

                        text: root.memoryPercent + "%"
                        color: root.memoryPercent >= 85
                            ? "#f38ba8"
                            : root.memoryPercent >= 65
                                ? "#fab387"
                                : root.theme.accent
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 11
                            rightMargin: 11
                            topMargin: 30
                        }

                        height: 3
                        radius: height / 2
                        color: root.glass(root.theme.foreground, 0.07)

                        Rectangle {
                            width: parent.width * root.memoryPercent / 100
                            height: parent.height
                            radius: parent.radius
                            color: root.theme.accent

                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            top: parent.top
                            leftMargin: 11
                            topMargin: 43
                        }

                        text: "Used  " + root.formatMemory(Math.max(0, root.memTotalKb - root.memAvailableKb))
                            + "  /  " + root.formatMemory(root.memTotalKb)
                        color: root.theme.mutedForeground
                        font.pixelSize: 9
                    }

                    Text {
                        anchors {
                            right: parent.right
                            top: parent.top
                            rightMargin: 11
                            topMargin: 43
                        }

                        text: "Available  " + root.formatMemory(root.memAvailableKb)
                        color: root.theme.mutedForeground
                        font.pixelSize: 9
                    }

                    Text {
                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                            leftMargin: 11
                            bottomMargin: 8
                        }

                        text: "Cache  " + root.formatMemory(root.memCachedKb)
                        color: root.theme.mutedForeground
                        font.pixelSize: 9
                    }

                    Text {
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                            rightMargin: 11
                            bottomMargin: 8
                        }

                        text: root.swapTotalKb > 0
                            ? "Swap  " + root.formatMemory(root.swapTotalKb - root.swapFreeKb)
                                + " / " + root.formatMemory(root.swapTotalKb)
                            : "Swap  disabled"
                        color: root.theme.mutedForeground
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 112
                    radius: 16
                    color: root.glass(root.theme.surface, 0.42)

                    Row {
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            topMargin: 9
                            leftMargin: 11
                            rightMargin: 11
                        }

                        height: 17

                        Text {
                            width: parent.width / 2
                            text: root.network.connected ? root.network.name : "Disconnected"
                            color: root.theme.foreground
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignRight
                            text: root.detailInterface + "  •  " + root.detailIpv4
                            color: root.theme.mutedForeground
                            font.pixelSize: 9
                            elide: Text.ElideLeft
                        }
                    }

                    Row {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 11
                            rightMargin: 11
                            topMargin: 38
                        }

                        Text {
                            width: parent.width / 2
                            text: "↓  " + root.formatBytes(root.downloadBps) + "/s"
                            color: root.theme.accent
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        Text {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignRight
                            text: "↑  " + root.formatBytes(root.uploadBps) + "/s"
                            color: root.theme.accent
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            leftMargin: 11
                            rightMargin: 11
                            topMargin: 66
                        }

                        height: 1
                        color: root.glass(root.theme.foreground, 0.06)
                    }

                    Row {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: 11
                            rightMargin: 11
                            bottomMargin: 11
                        }

                        Text {
                            width: parent.width / 2
                            text: "RX total  " + root.formatBytes(root.detailRxBytes)
                            color: root.theme.mutedForeground
                            font.pixelSize: 9
                        }

                        Text {
                            width: parent.width / 2
                            horizontalAlignment: Text.AlignRight
                            text: "TX total  " + root.formatBytes(root.detailTxBytes)
                            color: root.theme.mutedForeground
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }

    AppLauncher {
        id: launcher
        theme: root.theme
        anchorItem: launcherButton
    }

    NotificationCenter {
        id: notificationCenter
        theme: root.theme
        notifications: root.notifications
        anchorItem: notificationButton
    }

    SidePanel {
        id: sidePanel
        theme: root.theme
        audio: root.audio
        brightness: root.brightness
        anchorItem: barSurface
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcher.toggle()
        }

        function open(): void {
            launcher.openLauncher()
        }

        function close(): void {
            launcher.closeLauncher()
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "minimal-launcher"
        description: "Toggle application launcher"
        onPressed: launcher.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "minimal-notifications"
        description: "Toggle notification center"
        onPressed: notificationCenter.visible = !notificationCenter.visible
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "control-panel"
        description: "Toggle left control panel"
        onPressed: sidePanel.toggle()
    }

    IpcHandler {
        target: "control-panel"

        function toggle(): void {
            sidePanel.toggle()
        }

        function open(): void {
            sidePanel.openPanel()
        }

        function close(): void {
            sidePanel.closePanel()
        }
    }

    mask: Region {
        item: barSurface
    }
}
