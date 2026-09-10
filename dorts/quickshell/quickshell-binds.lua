-- Toggle the new left-side Quickshell control panel.
-- Change SUPER + A to any key combination you prefer.
hl.bind(
    "SUPER + A",
    hl.dsp.global("quickshell:control-panel"),
    {
        description = "Toggle Quickshell control panel"
    }
)

-- Give the translucent Quickshell surfaces real compositor blur.
hl.layer_rule({
    match = {
        namespace = "quickshell-shell"
    },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.10
})
