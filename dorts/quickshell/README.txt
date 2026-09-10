Complete Quickshell config layout

shell.qml
components/
  AppLauncher.qml
  Bar.qml
  NotificationCenter.qml
  SidePanel.qml
  StatusButton.qml
  Theme.qml
  WorkspaceButton.qml
services/
  AudioService.qml
  BrightnessService.qml
  NetworkService.qml
  NotificationService.qml
quickshell-binds.lua

Runtime command dependencies used by the config:
- wpctl (PipeWire/WirePlumber volume)
- brightnessctl (brightness control)
- nmcli (NetworkManager connection display)
- curl (weather in SidePanel.qml)

Weather location is set to Pensacola, FL.
