import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property int volumePercent: 0
    property bool muted: false

    function refresh() {
        if (!readProcess.running)
            readProcess.running = true
    }

    function toggleMute() {
        if (controlProcess.running)
            return

        controlProcess.command = [
            "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"
        ]
        controlProcess.running = true
    }

    function changeVolume(delta) {
        if (controlProcess.running)
            return

        const percent = Math.max(1, Math.round(Math.abs(delta) * 100))
        const suffix = delta >= 0 ? "%+" : "%-"

        controlProcess.command = [
            "wpctl", "set-volume", "-l", "1.5",
            "@DEFAULT_AUDIO_SINK@", percent + suffix
        ]
        controlProcess.running = true
    }

    Process {
        id: readProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                const match = output.match(/Volume:\s*([0-9.]+)/)
                if (match)
                    root.volumePercent = Math.round(Number(match[1]) * 100)

                root.muted = output.indexOf("[MUTED]") !== -1
            }
        }
    }

    Process {
        id: controlProcess
        onRunningChanged: {
            if (!running)
                refreshDelay.restart()
        }
    }

    Timer {
        id: refreshDelay
        interval: 80
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
