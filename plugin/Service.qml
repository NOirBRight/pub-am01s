import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "meter-model.mjs" as MeterModel

// AM01S panel. No screen match means no PanelWindow and no error.
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
  property string enginePath: ""
  property string snapshotStatus: "no-engine"
  property var snapshot: null
  property bool engineActive: false
  property bool componentReady: false
  property bool configReady: false
  property string engineOutput: ""

  // ADR 0004: the next snapshot starts five minutes after the previous run ends.
  readonly property int snapshotCooldownMs: 5 * 60 * 1000

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
    var nextEngine = ""
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
          if (typeof parsed.enginePath === "string") {
            var engineTrimmed = parsed.enginePath.replace(/^\s+|\s+$/g, "")
            if (engineTrimmed.length > 0) nextEngine = engineTrimmed
          }
        }
      } catch (e) {
        nextConnector = ""
        nextScale = 1.25
        nextEngine = ""
      }
    }
    if (root.connector !== nextConnector) root.connector = nextConnector
    if (root.uiScale !== nextScale) root.uiScale = nextScale
    if (root.enginePath !== nextEngine) root.enginePath = nextEngine
    root.configReady = true
    if (root.componentReady) root.ensureSnapshot()
  }

  // Config enginePath wins. Otherwise PUB_ENGINE. Never guess a binary.
  function resolvedEngine() {
    if (root.enginePath.length > 0) return root.enginePath
    return String(Quickshell.env("PUB_ENGINE") || "").replace(/^\s+|\s+$/g, "")
  }

  function ensureSnapshot() {
    if (root.resolvedEngine().length === 0) {
      cooldown.stop()
      if (!engineProc.running && !root.engineActive) {
        root.snapshotStatus = "no-engine"
        root.snapshot = null
      }
      return
    }
    if (engineProc.running || root.engineActive || cooldown.running) return
    root.startSnapshot()
  }

  function startSnapshot() {
    var bin = root.resolvedEngine()
    if (bin.length === 0) {
      root.snapshotStatus = "no-engine"
      root.snapshot = null
      return
    }
    if (engineProc.running || root.engineActive) return
    engineProc.command = [bin, "snapshot"]
    root.engineActive = true
    if (root.snapshotStatus !== "ok") root.snapshotStatus = "pending"
    engineProc.running = true
  }

  function finishSnapshot(exitCode, text) {
    root.engineActive = false
    var body = String(text || "")
    if (body.replace(/^\s+|\s+$/g, "").length === 0 && root.snapshotStatus === "ok" && root.snapshot !== null)
      return
    var checked = MeterModel.checkSnapshot(body)
    if (checked.status !== "ok") {
      root.snapshotStatus = checked.status
      root.snapshot = null
      return
    }
    try {
      root.snapshot = JSON.parse(body)
      root.snapshotStatus = "ok"
    } catch (e) {
      root.snapshotStatus = "unreadable"
      root.snapshot = null
    }
  }

  function armCooldown() {
    if (root.resolvedEngine().length === 0) return
    cooldown.restart()
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
    panelLoader.item.snapshot = root.snapshot
    panelLoader.item.snapshotStatus = root.snapshotStatus
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

  Process {
    id: engineProc
    stdout: StdioCollector {
      id: engineOut
      onStreamFinished: root.engineOutput = text
    }
    onExited: function(exitCode) {
      var body = root.engineOutput.length > 0 ? root.engineOutput : engineOut.text
      root.engineOutput = ""
      root.finishSnapshot(exitCode, body)
      root.armCooldown()
    }
    onRunningChanged: {
      if (!engineProc.running && root.engineActive) {
        root.finishSnapshot(1, "")
        root.armCooldown()
      }
    }
  }

  Timer {
    id: cooldown
    interval: root.snapshotCooldownMs
    repeat: false
    onTriggered: root.startSnapshot()
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
  onSnapshotChanged: root.pushPanel()
  onSnapshotStatusChanged: root.pushPanel()

  Component.onCompleted: {
    root.componentReady = true
    root.refreshScreen()
    if (root.configReady) root.ensureSnapshot()
  }
}
