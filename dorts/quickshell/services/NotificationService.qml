import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root

    property alias server: server
    readonly property int count: server.trackedNotifications.count

    function clearAll() {
        for (let i = server.trackedNotifications.count - 1; i >= 0; --i) {
            const notification = server.trackedNotifications.get(i)
            if (notification)
                notification.dismiss()
        }
    }

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true
        }
    }
}
