import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool connected: false
    property string name: "Disconnected"

    function refresh() {
        if (!readProcess.running)
            readProcess.running = true
    }

    Process {
        id: readProcess
        command: [
            "sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | "
            + "awk -F: '$2 == \"connected\" && ($1 == \"wifi\" || $1 == \"ethernet\") { print $3; exit }'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim()
                root.connected = value.length > 0
                root.name = root.connected ? value : "Disconnected"
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
