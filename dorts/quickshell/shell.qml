import QtQuick
import Quickshell
import "components"
import "services"

ShellRoot {
    id: root

    Theme {
        id: theme
    }

    AudioService {
        id: audio
    }

    BrightnessService {
        id: brightness
    }

    NetworkService {
        id: network
    }

    NotificationService {
        id: notifications
    }

    LockScreen {
        id: lockScreen

        theme: theme
    }

    WallpaperSwitcher {
        id: wallpaperSwitcher

        theme: theme
    }

    Bar {
        theme: theme
        audio: audio
        brightness: brightness
        network: network
        notifications: notifications
        lockScreen: lockScreen
    }

}
