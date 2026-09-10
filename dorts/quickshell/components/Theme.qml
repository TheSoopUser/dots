import QtQuick

QtObject {
    // Deep neutral base with a cool blue accent. Most windows draw these
    // colors with alpha so Hyprland's layer blur can show through them.
    readonly property color background: "#0b0f14"
    readonly property color surface: "#141a22"
    readonly property color surfaceHover: "#202937"
    readonly property color surfaceRaised: "#1b2330"

    readonly property color foreground: "#edf2f7"
    readonly property color mutedForeground: "#98a3b3"
    readonly property color subtleForeground: "#6f7b8d"

    readonly property color accent: "#9acbff"
    readonly property color accentStrong: "#6fb3ff"
    readonly property color accentMuted: "#466f9c"

    readonly property color border: "#2d3848"
    readonly property color borderBright: "#435064"
    readonly property color danger: "#ff8fa3"
    readonly property color warning: "#ffc98b"

    readonly property int barHeight: 40
    readonly property int radius: 16
    readonly property int largeRadius: 28
}
