-- FIRST: current Hyprland syntax
hl.bind(
    "SUPER + Super_L",
    hl.dsp.exec_cmd("qs ipc call launcher toggle"),
    {
        release = true,
    }
)
hl.bind(
    "SUPER + N",
    hl.dsp.global("quickshell:minimal-notifications"),
    { description = "Toggle Quickshell notification center" }
)

hl.bind(
    "SUPER + A",
    hl.dsp.global("quickshell:control-panel"),
    {
        description = "Toggle Quickshell control panel"
    }
)
hl.bind(
    "SUPER + L",
    hl.dsp.global("quickshell:lock-screen"),
    {
        description = "Lock session"
    }
)
hl.bind(
    "SUPER + W",
    hl.dsp.exec_cmd("qs ipc call wallpaper toggle"),
    {
        description = "Toggle wallpaper switcher"
    }
)