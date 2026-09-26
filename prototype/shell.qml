// PROTOTYPE — three radically different layouts for the AM01S 960×400 panel,
// switchable from the floating pill at the bottom (tap ‹ / ›). Read-only:
// real Snapshot from /tmp/pub-proto-snapshot.json, real Omarchy notification
// history; "dismiss" / "open" / DND / settings only change in-memory state.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  readonly property string dir: Quickshell.env("PUB_PROTO_DIR")
  readonly property var variants: ["A2", "A", "B", "C"]
  readonly property var variantNames: ({ A2: "A refined + motion", A: "Split: bars | inbox", B: "Rows + notification ticker", C: "Rail + focus + inbox" })
  property string variant: Quickshell.env("PUB_PROTO_VARIANT") || "A2"

  // Omarchy theme, live: the real plugin binds to qs.Commons Color/Style;
  // this standalone prototype re-reads the current theme's colors.toml.
  readonly property QtObject t: QtObject {
    property color bg: "#111c18"
    property color bgDark: "#0c1512"
    property color bgLight: "#23372B"
    property color sel: "#32473B"
    property color muted: "#53685B"
    property color fg: "#C1C497"
    property color fgBright: "#F7E8B2"
    property color fgDim: "#81B8A8"
    property color accent: "#509475"
    property color warn: "#a2734b"
    property color danger: "#FF5345"
    readonly property string font: "JetBrainsMono Nerd Font"
    Behavior on bg { ColorAnimation { duration: 600 } }
    Behavior on bgDark { ColorAnimation { duration: 600 } }
    Behavior on bgLight { ColorAnimation { duration: 600 } }
    Behavior on sel { ColorAnimation { duration: 600 } }
    Behavior on fg { ColorAnimation { duration: 600 } }
    Behavior on fgBright { ColorAnimation { duration: 600 } }
    Behavior on fgDim { ColorAnimation { duration: 600 } }
    Behavior on accent { ColorAnimation { duration: 600 } }
  }
  property string themeText: ""
  FileView {
    id: themeFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    onLoaded: {
      const raw = text(); if (raw === root.themeText) return
      root.themeText = raw
      const c = {}
      for (const line of raw.split("\n")) { const m = line.match(/^\s*([a-z_0-9]+)\s*=\s*"([^"]+)"/); if (m) c[m[1]] = m[2] }
      const pick = (...ks) => { for (const k of ks) if (c[k]) return c[k]; return undefined }
      const set = (role, ...ks) => { const v = pick(...ks); if (v) root.t[role] = v }
      set("bg", "background"); set("fg", "foreground"); set("accent", "accent", "color4", "blue")
      set("bgDark", "dark_background"); if (!c.dark_background) root.t.bgDark = Qt.darker(root.t.bg, 1.25)
      set("bgLight", "lighter_background"); if (!c.lighter_background) root.t.bgLight = Qt.lighter(root.t.bg, 1.5)
      set("sel", "selection", "selection_background"); if (!pick("selection", "selection_background")) root.t.sel = Qt.lighter(root.t.bg, 1.8)
      set("muted", "muted", "color8"); set("fgBright", "bright_foreground", "color15"); set("fgDim", "dark_foreground", "color7")
      set("warn", "orange", "color3", "yellow"); set("danger", "red", "color1")
      root.lastAction = "theme " + (c.mode || "?")
    }
  }
  Timer { interval: 2000; repeat: true; running: true; onTriggered: themeFile.reload() }

  // Own UI scale, independent of Hyprland's monitor scale.
  property real uiScale: Number(Quickshell.env("PUB_PROTO_SCALE") || 1.25)
  readonly property var scales: [1, 1.15, 1.25, 1.4]

  // ---- state (in memory only) ----
  property var allProviders: []
  property int limit: Number(Quickshell.env("PUB_PROTO_LIMIT") || 0)               // 0 = all; else simulate only N signed-in subscriptions
  readonly property var providers: limit ? allProviders.filter(p => !p.error).slice(0, limit) : allProviders
  property var notes: []
  property var dismissed: ({})
  property bool dnd: false
  property string expanded: Quickshell.env("PUB_PROTO_EXPAND") || ""        // provider id expanded in place
  property string lastAction: "—"     // surfaced state line

  function icon(id) { return "file://" + dir + "/icons/" + id + ".svg" }
  function short(w) { return w.shortLabel || w.label.replace(/ models$/i, "") }
  // Engine would own this too (Provider catalog), like shortLabel.
  function shortName(p) { return p.shortName || ({ "ollama-cloud": "Ollama", "opencode-go": "OpenCode", "commandcode": "Cmd Code" })[p.id] || p.name }
  function pct(r) { return r === null || r === undefined ? "—" : Math.round(r * 100) + "%" }
  function level(r) { return r === null || r === undefined ? t.muted : r <= 0.05 ? t.danger : r <= 0.2 ? t.warn : t.accent }
  function primary(p) { return (p.windows || []).find(w => w.primary) || (p.windows || [])[0] }
  function ago(ms) {
    const s = Math.max(0, (Date.now() - ms) / 1000)
    return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d"
  }
  function visibleNotes() { return notes.filter(n => !dismissed[n.file]) }
  function dismiss(n) { const d = Object.assign({}, dismissed); d[n.file] = true; dismissed = d; lastAction = "dismiss " + n.app }
  function openNote(n) { lastAction = "open " + n.app + (n.execArgv ? " → " + n.execArgv : " (no execArgv)") }
  function toggle(id) { expanded = expanded === id ? "" : id; lastAction = "expand " + (expanded || "none") }
  function toggleDnd() { dnd = !dnd; lastAction = "DND " + (dnd ? "on" : "off") }
  function openSettings() { lastAction = "summon Settings Overlay on main screen" }

  FileView {
    path: "/tmp/pub-proto-snapshot.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.allProviders = JSON.parse(text()).providers } catch (e) { root.allProviders = [] }
    }
  }

  Process {
    id: history
    running: true
    command: ["sh", "-c", "cd \"$HOME/.local/state/omarchy/notifications/history\" 2>/dev/null && for f in *.json; do printf '%s\\t' \"$f\"; tr -d '\\n' < \"$f\"; echo; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        const out = []
        for (const line of text.split("\n")) {
          const tab = line.indexOf("\t")
          if (tab < 0) continue
          try { const n = JSON.parse(line.slice(tab + 1)); n.file = line.slice(0, tab); out.push(n) } catch (e) {}
        }
        out.sort((a, b) => b.timestamp - a.timestamp)
        root.notes = out
      }
    }
  }
  Timer { interval: 5000; repeat: true; running: true; onTriggered: history.running = true }
  Timer { interval: 1500; running: true; onTriggered: console.log("PROBE providers", root.providers.length, "notes", root.notes.length, "screen", win.screen ? win.screen.name : "null") }
  Timer { interval: 30000; repeat: true; running: true; onTriggered: root.notesChanged() } // refresh "ago"

  PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.width === 960 && s.height === 400) ?? Quickshell.screens.find(s => s.name === "HDMI-A-3") ?? null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "pub-am01s-prototype"
    color: root.t.bg

    Loader {
      id: loader
      // Design in physical pixels (960×400) and scale to the logical size,
      // because Hyprland currently runs AM01S at scale 2 (logical 480×200).
      width: Math.round(960 / root.uiScale); height: Math.round(400 / root.uiScale)
      transform: Scale { xScale: win.width / loader.width; yScale: win.height / loader.height }
      function show() { setSource("Variant" + root.variant + ".qml", { r: root }) }
      Component.onCompleted: show()
      Connections { target: root; function onVariantChanged() { loader.show() } }
    }
    Item {
      width: 960; height: 400
      transform: Scale { xScale: win.width / 960; yScale: win.height / 400 }
    // Floating switcher — obviously not part of the design.
      // Tap the bottom edge to bring the switcher back; it hides after 4 s.
      property bool pillShown: true
      Timer { id: hide; interval: 4000; running: true; onTriggered: parent.pillShown = false }
      MouseArea { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 14
        onClicked: { parent.pillShown = true; hide.restart() } }
      Rectangle {
        opacity: parent.pillShown ? 1 : 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 4 }
        width: row.implicitWidth + 16; height: 26; radius: 13
        color: "#e0ffffff"; border.color: "#ff00aa"; border.width: 2
        Row {
          id: row; anchors.centerIn: parent; spacing: 10
          Text { text: "‹"; font.pixelSize: 18; color: "#000"
            MouseArea { anchors.fill: parent; anchors.margins: -10
              onClicked: { const i = root.variants.indexOf(root.variant); root.variant = root.variants[(i + root.variants.length - 1) % root.variants.length] } } }
          Text { text: root.variant + " · " + root.variantNames[root.variant] + "   [" + root.lastAction + "]"; font.pixelSize: 11; color: "#000"; anchors.verticalCenter: parent.verticalCenter }
          Text { text: "n=" + (root.limit || "all"); font.pixelSize: 11; font.bold: true; color: "#ff00aa"; anchors.verticalCenter: parent.verticalCenter
          MouseArea { anchors.fill: parent; anchors.margins: -8
            onClicked: { root.limit = (root.limit + 1) % 5; root.expanded = ""; root.lastAction = "providers " + (root.limit || "all") } } }
        Text { text: "×" + root.uiScale; font.pixelSize: 11; font.bold: true; color: "#0077ff"; anchors.verticalCenter: parent.verticalCenter
          MouseArea { anchors.fill: parent; anchors.margins: -8
            onClicked: { const i = root.scales.indexOf(root.uiScale); root.uiScale = root.scales[(i + 1) % root.scales.length]; loader.show(); root.lastAction = "scale " + root.uiScale } } }
        Text { text: "›"; font.pixelSize: 18; color: "#000"
            MouseArea { anchors.fill: parent; anchors.margins: -10
              onClicked: { hide.restart(); const i = root.variants.indexOf(root.variant); root.variant = root.variants[(i + 1) % root.variants.length] } } }
        }
      }
    }

  }
}
