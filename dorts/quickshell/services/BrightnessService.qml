import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property int percent: 0

    function refresh() {
        if (!readProcess.running)
            readProcess.running = true
    }

    function change(increase) {
        if (controlProcess.running)
            return

        controlProcess.command = [
            "brightnessctl", "set", increase ? "5%+" : "5%-"
        ]
        controlProcess.running = true
    }

    Process {
        id: readProcess
        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                const match = output.match(/,(\d+)%/)
                if (match)
                    root.percent = Number(match[1])
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
        interval: 1200
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
