import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "meter-model.mjs" as MeterModel
import "settings-model.mjs" as SettingsModel

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

  property bool settingsOpen: false
  property var overlayScreen: null
  property var catalogDoc: null
  property var settingsDoc: null
  property string settingsStatus: ""
  property string settingsError: ""
  property bool catalogFresh: false
  property bool settingsFresh: false
  property string jobQueue: "[]"
  property string activeJob: ""
  property int activeGeneration: 0
  property bool settingsActive: false
  property string settingsStdoutText: ""
  property string settingsStderrText: ""
  property bool consumingSignal: false
  property bool snapshotAfterSettings: false

  readonly property var settingsView: SettingsModel.presentSettings(catalogDoc, settingsDoc, snapshot)
  // Catalog login fields only. The plugin has no login table of its own.
  readonly property var overlayProviders: SettingsModel.withLogin(settingsView.providers, catalogDoc, snapshot)
  readonly property string settingsMessage: {
    if (root.resolvedEngine().length === 0 || root.settingsStatus === "no-engine")
      return "Engine is not configured"
    if (root.settingsStatus === "error")
      return root.settingsError.length > 0 ? root.settingsError : "Engine 没有返回设置"
    if (root.settingsStatus !== "ok") return "读取中"
    return root.settingsError
  }
  // Menu touch file. Runtime dir when set, otherwise the user cache.
  readonly property string settingsSignalPath: {
    var runtime = String(Quickshell.env("XDG_RUNTIME_DIR") || "").replace(/^\s+|\s+$/g, "").replace(/\/+$/g, "")
    if (runtime.length > 0) return runtime + "/pub-am01s/open-settings"
    var home = String(Quickshell.env("HOME") || "").replace(/^\s+|\s+$/g, "").replace(/\/+$/g, "")
    if (home.length === 0) return ""
    return home + "/.cache/pub-am01s/open-settings"
  }

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

  // file:// URL from this plugin document, as a filesystem path.
  function localPath(value) {
    var text = String(value || "")
    if (text.indexOf("file://") === 0) {
      text = text.slice(7)
      if (text.indexOf("localhost/") === 0)
        text = text.slice("localhost".length)
      try {
        text = decodeURIComponent(text)
      } catch (e) {}
    }
    return text
  }

  // Pinned asset lives next to this file: plugin/bin/pub-engine.mjs.
  function pinnedEngine() {
    return root.localPath(Qt.resolvedUrl("bin/pub-engine.mjs"))
  }

  // Config enginePath wins. Otherwise the pinned file beside this plugin.
  function resolvedEngine() {
    if (root.enginePath.length > 0) return root.enginePath
    return root.pinnedEngine()
  }

  // enginePath is executed as given. The pinned asset is an ES module, so Node runs it.
  function engineCommand(args) {
    var command = []
    if (root.enginePath.length > 0)
      command.push(root.enginePath)
    else {
      command.push("node")
      command.push(root.pinnedEngine())
    }
    var list = args || []
    var count = list.length ? list.length : 0
    for (var i = 0; i < count; i++)
      command.push(String(list[i]))
    return command
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
    engineProc.command = root.engineCommand(["snapshot"])
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
    panelLoader.item.shell = Qt.binding(function() { return root.shell })
    panelLoader.item.snapshot = Qt.binding(function() { return root.snapshot })
    panelLoader.item.snapshotStatus = Qt.binding(function() { return root.snapshotStatus })
  }

  function readJobs() {
    try {
      var jobs = JSON.parse(root.jobQueue)
      if (Array.isArray(jobs)) return jobs
    } catch (e) {}
    return []
  }

  function commandFor(job) {
    if (!job) return []
    if (job.kind === "catalog") return SettingsModel.catalogCommand()
    if (job.kind === "settings") return SettingsModel.settingsCommand()
    if (job.field === "enabled") return SettingsModel.enabledCommand(job.id, job.enabled === true)
    if (job.field === "remaining-mode") return SettingsModel.remainingModeCommand(job.remainingMode === true)
    return []
  }

  function enqueueJob(job) {
    var jobs = root.readJobs()
    jobs.push(job)
    root.jobQueue = JSON.stringify(jobs)
    Qt.callLater(function() { root.pumpJobs() })
  }

  function pumpJobs() {
    if (root.settingsActive || settingsProc.running) return
    var jobs = root.readJobs()
    if (jobs.length === 0) return
    var job = jobs.shift()
    root.jobQueue = JSON.stringify(jobs)
    var bin = root.resolvedEngine()
    if (bin.length === 0) {
      root.jobQueue = "[]"
      root.settingsStatus = "no-engine"
      root.settingsError = ""
      return
    }
    var argv = root.commandFor(job)
    var argc = argv && argv.length ? argv.length : 0
    if (argc === 0) {
      root.pumpJobs()
      return
    }
    root.activeGeneration += 1
    root.activeJob = JSON.stringify(job || {})
    root.settingsStdoutText = ""
    root.settingsStderrText = ""
    root.settingsActive = true
    settingsFailTimer.stop()
    settingsProc.command = root.engineCommand(argv)
    settingsProc.running = true
  }

  function engineError(text, fallback) {
    var trimmed = String(text || "").replace(/^\s+|\s+$/g, "")
    if (trimmed.length > 240) trimmed = trimmed.slice(0, 240)
    return trimmed.length > 0 ? trimmed : fallback
  }

  function markReady() {
    if (!root.catalogFresh || !root.settingsFresh) return
    root.settingsStatus = "ok"
    root.settingsError = ""
  }

  function acceptCatalog(ok, out, err) {
    if (!ok) {
      root.catalogFresh = false
      root.settingsStatus = "error"
      root.settingsError = root.engineError(err, "catalog 失败")
      return
    }
    var parsed = SettingsModel.parseDocument(out)
    if (!parsed || parsed.ok !== true) {
      root.catalogFresh = false
      root.settingsStatus = "error"
      root.settingsError = "无法读取 catalog"
      return
    }
    root.catalogDoc = parsed.value
    root.catalogFresh = true
    root.markReady()
  }

  function acceptSettings(ok, out, err) {
    if (!ok) {
      root.settingsFresh = false
      root.settingsStatus = "error"
      root.settingsError = root.engineError(err, "settings 失败")
      return
    }
    var parsed = SettingsModel.parseDocument(out)
    if (!parsed || parsed.ok !== true) {
      root.settingsFresh = false
      root.settingsStatus = "error"
      root.settingsError = "无法读取 settings"
      return
    }
    root.settingsDoc = parsed.value
    root.settingsFresh = true
    root.markReady()
  }

  function acceptSet(ok, err) {
    var job = {}
    try { job = JSON.parse(root.activeJob || "{}") } catch (e) { job = {} }
    if (!ok) {
      root.settingsError = root.engineError(err, "设置没有写入")
      root.enqueueJob({ kind: "settings" })
      return
    }
    if (job.field === "enabled")
      root.settingsDoc = SettingsModel.withEnabled(root.settingsDoc, job.id, job.enabled === true)
    else if (job.field === "remaining-mode")
      root.settingsDoc = SettingsModel.withRemainingMode(root.settingsDoc, job.remainingMode === true)
    root.settingsError = ""
    if (root.catalogDoc && root.settingsDoc) {
      root.catalogFresh = true
      root.settingsFresh = true
      root.settingsStatus = "ok"
    }
    root.refreshAfterSettings()
  }

  function finishSettingsJob(generation, exitCode, out, err) {
    if (generation !== root.activeGeneration || !root.settingsActive) return
    settingsFailTimer.stop()
    root.settingsActive = false
    var job = {}
    try { job = JSON.parse(root.activeJob || "{}") } catch (e) { job = {} }
    var ok = Number(exitCode) === 0
    var kind = String(job.kind || "")
    if (kind === "catalog") root.acceptCatalog(ok, out, err)
    else if (kind === "settings") root.acceptSettings(ok, out, err)
    else if (kind === "set") root.acceptSet(ok, err)
    Qt.callLater(function() { root.pumpJobs() })
  }

  function primeSettings() {
    if (root.resolvedEngine().length === 0) {
      root.jobQueue = "[]"
      root.settingsStatus = "no-engine"
      root.settingsError = ""
      root.catalogFresh = false
      root.settingsFresh = false
      return
    }
    root.catalogFresh = false
    root.settingsFresh = false
    if (root.settingsStatus !== "ok") root.settingsStatus = "loading"
    root.enqueueJob({ kind: "catalog" })
    root.enqueueJob({ kind: "settings" })
  }

  function queueEnabled(id, enabled) {
    if (root.resolvedEngine().length === 0) return
    var on = enabled === true
    root.settingsDoc = SettingsModel.withEnabled(root.settingsDoc, id, on)
    root.enqueueJob({
      kind: "set",
      field: "enabled",
      id: String(id),
      enabled: on,
    })
  }

  function queueRemainingMode(remainingMode) {
    if (root.resolvedEngine().length === 0) return
    var on = remainingMode === true
    if (SettingsModel.remainingModeOf(root.settingsDoc) === on) return
    root.settingsDoc = SettingsModel.withRemainingMode(root.settingsDoc, on)
    root.enqueueJob({
      kind: "set",
      field: "remaining-mode",
      remainingMode: on,
    })
  }

  // Focused output, skipping the AM01S. Null when no other screen exists.
  function pickOverlayScreen() {
    var screens = Quickshell.screens || []
    var focusedName = ""
    try {
      var monitor = Hyprland.focusedMonitor
      if (monitor) focusedName = String(monitor.name || "")
    } catch (e) {
      focusedName = ""
    }
    var fallback = null
    for (var i = 0; i < screens.length; i++) {
      var screen = screens[i]
      if (!screen || screen === root.panelScreen) continue
      if (!fallback) fallback = screen
      if (focusedName.length > 0 && String(screen.name || "") === focusedName) return screen
    }
    return fallback
  }

  function ensureOverlayScreen() {
    if (!root.settingsOpen) return
    var screens = Quickshell.screens || []
    var currentOk = false
    if (root.overlayScreen && root.overlayScreen !== root.panelScreen) {
      for (var i = 0; i < screens.length; i++) {
        if (screens[i] === root.overlayScreen) currentOk = true
      }
    }
    if (currentOk) return
    root.overlayScreen = root.pickOverlayScreen()
  }

  function openSettings() {
    root.settingsOpen = true
    root.overlayScreen = root.pickOverlayScreen()
    root.ensureOverlayScreen()
    root.primeSettings()
  }

  function closeSettings() {
    root.settingsOpen = false
  }

  function pushSettingsOverlay() {
    var item = settingsLoader.item
    if (!item) return
    item.targetScreen = Qt.binding(function() { return root.overlayScreen })
    item.providers = Qt.binding(function() { return root.overlayProviders })
    item.enginePath = Qt.binding(function() { return root.resolvedEngine() })
    item.engineLead = Qt.binding(function() { return root.engineCommand([]) })
    item.remainingMode = Qt.binding(function() { return root.settingsView.remainingMode === true })
    item.status = Qt.binding(function() { return root.settingsStatus })
    item.message = Qt.binding(function() { return root.settingsMessage })
  }

  function refreshAfterSettings() {
    if (engineProc.running || root.engineActive) {
      root.snapshotAfterSettings = true
      return
    }
    root.snapshotAfterSettings = false
    cooldown.stop()
    root.startSnapshot()
  }

  function pollSettingsSignal() {
    if (root.settingsSignalPath.length === 0 || root.consumingSignal) return
    if (settingsProbe.running || signalClear.running) return
    settingsProbe.command = ["test", "-e", root.settingsSignalPath]
    settingsProbe.running = true
  }

  function consumeSettingsSignal() {
    if (root.consumingSignal) return
    root.consumingSignal = true
    root.openSettings()
    signalClear.command = ["rm", "-f", "--", root.settingsSignalPath]
    signalClear.running = true
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
      if (root.snapshotAfterSettings) {
        root.snapshotAfterSettings = false
        root.startSnapshot()
        return
      }
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
    function onScreensChanged() {
      root.refreshScreen()
      root.ensureOverlayScreen()
    }
  }

  Connections {
    target: Hyprland.monitors
    function onValuesChanged() { root.refreshScreen() }
  }

  // Hyprland IPC fills monitor size a moment after the service is created.
  // Until then every match fails and screensChanged does not fire again.
  Timer {
    interval: 300
    repeat: true
    running: root.panelScreen === null
    onTriggered: root.refreshScreen()
  }

  Loader {
    id: panelLoader
    active: root.panelScreen !== null
    source: active ? "PanelSurface.qml" : ""
    onLoaded: root.pushPanel()
  }

  // Inbox button. The loader stays inactive when no AM01S is matched.
  Connections {
    target: panelLoader.item
    function onSettingsRequested() { root.openSettings() }
  }

  // Same window with the panel unplugged: this loader does not follow panelLoader.
  Loader {
    id: settingsLoader
    active: root.settingsOpen && root.overlayScreen !== null
    source: active ? "SettingsOverlay.qml" : ""
    onLoaded: root.pushSettingsOverlay()
  }

  Connections {
    target: settingsLoader.item
    function onCloseRequested() { root.closeSettings() }
    function onEnabledToggled(id, enabled) { root.queueEnabled(id, enabled) }
    function onRemainingModeToggled(remainingMode) { root.queueRemainingMode(remainingMode) }
    function onLoginChanged() { root.refreshAfterSettings() }
  }

  Process {
    id: settingsProc
    stdout: StdioCollector {
      id: settingsOut
      onStreamFinished: root.settingsStdoutText = text
    }
    stderr: StdioCollector {
      id: settingsErr
      onStreamFinished: root.settingsStderrText = text
    }
    onExited: function(exitCode) {
      settingsFailTimer.stop()
      var generation = root.activeGeneration
      var code = exitCode
      // Let the stdio collectors finish before reading them.
      Qt.callLater(function() {
        var out = root.settingsStdoutText.length > 0 ? root.settingsStdoutText : settingsOut.text
        var err = root.settingsStderrText.length > 0 ? root.settingsStderrText : settingsErr.text
        root.settingsStdoutText = ""
        root.settingsStderrText = ""
        root.finishSettingsJob(generation, code, out, err)
      })
    }
    onRunningChanged: {
      if (!settingsProc.running && root.settingsActive) {
        settingsFailTimer.generation = root.activeGeneration
        settingsFailTimer.restart()
      }
    }
  }

  Timer {
    id: settingsFailTimer
    property int generation: 0
    interval: 200
    repeat: false
    onTriggered: root.finishSettingsJob(generation, 1, "", "")
  }

  Timer {
    interval: 500
    repeat: true
    running: root.settingsSignalPath.length > 0
    onTriggered: root.pollSettingsSignal()
  }

  Process {
    id: settingsProbe
    onExited: function(exitCode) {
      if (exitCode !== 0 || root.consumingSignal) return
      root.consumeSettingsSignal()
    }
  }

  Process {
    id: signalClear
    property bool sawRunning: false
    onRunningChanged: {
      if (signalClear.running) signalClear.sawRunning = true
      else if (signalClear.sawRunning) {
        signalClear.sawRunning = false
        root.consumingSignal = false
      }
    }
    onExited: {
      signalClear.sawRunning = false
      root.consumingSignal = false
    }
  }

  onConnectorChanged: root.refreshScreen()
  onPanelScreenChanged: {
    root.pushPanel()
    root.ensureOverlayScreen()
  }
  onUiScaleChanged: root.pushPanel()
  onSnapshotChanged: root.pushPanel()
  onSnapshotStatusChanged: root.pushPanel()

  Component.onCompleted: {
    root.componentReady = true
    root.refreshScreen()
    if (root.configReady) root.ensureSnapshot()
  }
}
