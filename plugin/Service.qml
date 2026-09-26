import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons

// Empty AM01S panel. No screen match means no PanelWindow and no error.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string configHome: {
    var configured = String(Quickshell.env("XDG_CONFIG_HOME") || "")
    if (configured.length > 0) return configured
    return String(Quickshell.env("HOME") || "") + "/.config"
  }
  readonly property string configPath: configHome + "/pub-am01s/config.json"

  property string connector: ""
  property real uiScale: 1.25
  property var panelScreen: null

  function clampUiScale(value) {
    var n = Number(value)
    if (!isFinite(n)) return 1.25
    if (n < 1) return 1
    if (n > 1.4) return 1.4
    return n
  }

  function applyConfig(raw) {
    var nextConnector = ""
    var nextScale = 1.25
    var text = String(raw || "")
    if (text.length > 0) {
      try {
        var parsed = JSON.parse(text)
        if (parsed && typeof parsed === "object") {
          if (typeof parsed.connector === "string") {
            var trimmed = parsed.connector.replace(/^\s+|\s+$/g, "")
            if (trimmed.length > 0) nextConnector = trimmed
          }
          if (parsed.uiScale !== undefined && parsed.uiScale !== null)
            nextScale = root.clampUiScale(parsed.uiScale)
        }
      } catch (e) {
        nextConnector = ""
        nextScale = 1.25
      }
    }
    if (root.connector !== nextConnector) root.connector = nextConnector
    if (root.uiScale !== nextScale) root.uiScale = nextScale
  }

  // Hyprland reports either physical pixels or logical pixels times scale.
  function modeIsPanel(width, height, scale) {
    var w = Number(width)
    var h = Number(height)
    var s = Number(scale)
    if (!isFinite(w) || !isFinite(h)) return false
    if (w === 960 && h === 400) return true
    if (!isFinite(s) || s <= 0) return false
    return Math.round(w * s) === 960 && Math.round(h * s) === 400
  }

  function monitorMatches(monitor) {
    if (!monitor) return false
    if (!root.modeIsPanel(monitor.width, monitor.height, monitor.scale)) return false
    if (root.connector.length > 0) return String(monitor.name || "") === root.connector
    return String(monitor.description || "").indexOf("ChangHong Electric Co.Ltd 0x0030") >= 0
  }

  function monitorFor(screen) {
    if (!screen) return null
    var signature = String(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "")
    if (signature.length === 0) return null
    try {
      return Hyprland.monitorFor(screen)
    } catch (e) {
      return null
    }
  }

  function refreshScreen() {
    var found = null
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      if (root.monitorMatches(root.monitorFor(screen))) {
        found = screen
        break
      }
    }
    if (root.panelScreen !== found) root.panelScreen = found
  }

  function pushPanel() {
    if (!panelLoader.item) return
    panelLoader.item.targetScreen = root.panelScreen
    panelLoader.item.uiScale = root.uiScale
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onFileChanged: reload()
    onLoadFailed: root.applyConfig("")
  }

  Connections {
    target: Quickshell
    function onScreensChanged() { root.refreshScreen() }
  }

  Connections {
    target: Hyprland.monitors
    function onValuesChanged() { root.refreshScreen() }
  }

  Loader {
    id: panelLoader
    active: root.panelScreen !== null
    source: active ? "PanelSurface.qml" : ""
    onLoaded: root.pushPanel()
  }

  onConnectorChanged: root.refreshScreen()
  onPanelScreenChanged: root.pushPanel()
  onUiScaleChanged: root.pushPanel()

  Component.onCompleted: root.refreshScreen()
}
