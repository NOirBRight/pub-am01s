import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "inbox-model.mjs" as InboxModel

// Right-hand notification history. Parsing stays in inbox-model.mjs.
Item {
  id: root

  signal settingsRequested()

  property var shell: null

  readonly property string stateHome: {
    var configured = String(Quickshell.env("XDG_STATE_HOME") || "")
    if (configured.length > 0) return configured
    return String(Quickshell.env("HOME") || "") + "/.local/state"
  }
  readonly property string historyDir: stateHome + "/omarchy/notifications/history"

  // Third-party plugins cannot read the notification service. DND is the
  // shell IPC plus the file that service writes.
  property bool dnd: false
  readonly property string dndPath: String(Quickshell.env("HOME") || "") + "/.local/state/omarchy/notifications.json"

  property string themeOrange: ""
  property string themeBgLight: ""
  property string themeSel: ""
  property string themeFgBright: ""
  property string themeFgDim: ""
  property string themeBgDark: ""

  readonly property color bgLight: themeBgLight.length > 0 ? themeBgLight : Qt.lighter(Color.background, 1.45)
  readonly property color sel: themeSel.length > 0 ? themeSel : Qt.lighter(Color.background, 1.8)
  readonly property color fgBright: themeFgBright.length > 0 ? themeFgBright : Color.foreground
  readonly property color fgDim: themeFgDim.length > 0 ? themeFgDim : Qt.darker(Color.foreground, 1.3)
  readonly property color bgDark: themeBgDark.length > 0 ? themeBgDark : Qt.darker(Color.background, 1.25)
  readonly property color warnColor: themeOrange.length > 0 ? themeOrange : Color.urgent
  readonly property color dangerColor: Color.urgent

  property var pendingDelete: ({})
  property bool readQueued: false
  property int activeSerial: 0
  property int appliedSerial: -1
  property bool focusQueued: false
  property string pendingFocusApp: ""
  property string pendingFocusSummary: ""
  property int pendingFocusSerial: 0
  property int focusSerial: 0

  // path \t base64, one history file per line. textFromBase64 owns UTF-8.
  readonly property string readScript:
    "dir=\"$1\"\n" +
    "[[ -d \"$dir\" ]] || exit 0\n" +
    "find \"$dir\" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null | " +
    "while IFS= read -r -d '' f; do\n" +
    "  printf '%s\\t' \"$f\"\n" +
    "  base64 -w 0 -- \"$f\" 2>/dev/null || true\n" +
    "  printf '\\n'\n" +
    "done\n"

  readonly property string watchScript:
    "dir=\"$1\"\n" +
    "mkdir -p -- \"$dir\" 2>/dev/null || true\n" +
    "if ! command -v inotifywait >/dev/null 2>&1; then\n" +
    "  while true; do sleep 2; printf 'changed\\n'; done\n" +
    "fi\n" +
    "while true; do\n" +
    "  if ! inotifywait -q -e close_write -e create -e delete -e moved_to -e moved_from -e move -- \"$dir\" >/dev/null; then\n" +
    "    sleep 1\n" +
    "    mkdir -p -- \"$dir\" 2>/dev/null || true\n" +
    "  fi\n" +
    "  printf 'changed\\n'\n" +
    "done\n"

  function isHistoryFile(path) {
    var file = String(path || "")
    var dir = root.historyDir
    if (!file || !dir) return false
    if (file.indexOf("\n") >= 0 || file.indexOf("\0") >= 0) return false
    if (dir.charAt(dir.length - 1) !== "/") dir += "/"
    if (file.indexOf(dir) !== 0) return false
    var name = file.slice(dir.length)
    if (!name || name === "." || name === ".." || name.indexOf("/") >= 0) return false
    return name.length > 5 && name.slice(-5) === ".json"
  }

  function isPending(path) {
    return Object.prototype.hasOwnProperty.call(root.pendingDelete, path)
  }

  function flatRow(row) {
    var icon = row.icon || {}
    return {
      path: String(row.path || ""),
      app: String(row.app || ""),
      summary: String(row.summary || ""),
      body: String(row.body || ""),
      timeLabel: String(row.timeLabel || ""),
      fresh: !!row.fresh,
      iconKind: String(icon.kind || "initial"),
      iconPath: String(icon.path || ""),
      iconName: String(icon.name || ""),
      iconNames: (icon.names || []).join("\n"),
      iconLetter: String(icon.letter || "?"),
      iconColor: String(icon.color || "#509475"),
      actionJson: row.action ? JSON.stringify(row.action) : "",
      actionOpensImage: row.actionOpensImage === true
    }
  }

  function sameRow(current, next) {
    return String(current.path) === next.path
      && String(current.app) === next.app
      && String(current.summary) === next.summary
      && String(current.body) === next.body
      && String(current.timeLabel) === next.timeLabel
      && (!!current.fresh) === next.fresh
      && String(current.iconKind) === next.iconKind
      && String(current.iconPath) === next.iconPath
      && String(current.iconName) === next.iconName
      && String(current.iconNames || "") === next.iconNames
      && (!!current.actionOpensImage) === next.actionOpensImage
      && String(current.iconLetter) === next.iconLetter
      && String(current.iconColor) === next.iconColor
      && String(current.actionJson || "") === next.actionJson
  }

  function syncRows(rows) {
    var wanted = []
    var seen = {}
    for (var i = 0; i < rows.length; i++) {
      seen[rows[i].path] = true
      if (!root.isPending(rows[i].path)) wanted.push(root.flatRow(rows[i]))
    }
    var pending = root.pendingDelete
    var nextPending = {}
    var pendingChanged = false
    for (var key in pending) {
      if (!Object.prototype.hasOwnProperty.call(pending, key)) continue
      if (seen[key]) nextPending[key] = true
      else pendingChanged = true
    }
    if (pendingChanged) root.pendingDelete = nextPending

    var keep = {}
    for (var w = 0; w < wanted.length; w++) keep[wanted[w].path] = true
    for (var r = rowsModel.count - 1; r >= 0; r--) {
      if (!keep[rowsModel.get(r).path]) rowsModel.remove(r, 1)
    }
    for (var index = 0; index < wanted.length; index++) {
      var found = -1
      for (var j = index; j < rowsModel.count; j++) {
        if (rowsModel.get(j).path === wanted[index].path) { found = j; break }
      }
      if (found < 0) rowsModel.insert(index, wanted[index])
      else if (found !== index) rowsModel.move(found, index, 1)
      var current = rowsModel.get(index)
      if (!current || !root.sameRow(current, wanted[index])) rowsModel.set(index, wanted[index])
    }
  }

  function ingest(payload) {
    var files = []
    var lines = String(payload || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var tab = line.indexOf("\t")
      if (tab < 0) continue
      var path = line.slice(0, tab)
      var encoded = line.slice(tab + 1)
      files.push({ path: path, text: encoded ? InboxModel.textFromBase64(encoded) : "" })
    }
    root.syncRows(InboxModel.readInbox(files, Date.now()))
  }

  function finishRead(payload) {
    if (root.appliedSerial === root.activeSerial) return
    root.appliedSerial = root.activeSerial
    root.ingest(payload)
  }

  function startRead() {
    if (readProc.running) {
      root.readQueued = true
      return
    }
    root.readQueued = false
    root.activeSerial += 1
    root.appliedSerial = -1
    readProc.command = ["bash", "-c", root.readScript, "--", root.historyDir]
    readProc.running = true
  }

  function scheduleRead() {
    readTimer.restart()
  }

  function openAction(actionJson) {
    if (!actionJson) return
    var argv = null
    try { argv = JSON.parse(actionJson) } catch (e) { return }
    if (!argv || !argv.length) return
    Util.execArgv(argv)
  }

  function themeIconUrl(namesText) {
    var names = String(namesText || "").split("\n")
    for (var i = 0; i < names.length; i++) {
      var name = names[i]
      if (!name) continue
      var found = Quickshell.iconPath(name, true)
      if (found && String(found).length > 0) return String(found)
    }
    return ""
  }

  function activate(model) {
    if (!model) return
    // A picture command, such as tensaku-edit on a screenshot, is not the app.
    if (model.actionJson && model.actionOpensImage !== true) {
      root.openAction(model.actionJson)
      return
    }
    root.focusSerial += 1
    root.pendingFocusSerial = root.focusSerial
    root.pendingFocusApp = String(model.app || "")
    root.pendingFocusSummary = String(model.summary || "")
    if (focusProc.running) {
      root.focusQueued = true
      return
    }
    root.startFocus()
  }

  function startFocus() {
    focusProc.command = ["hyprctl", "clients", "-j"]
    focusProc.running = true
  }

  function finishFocus(payload) {
    var serial = root.pendingFocusSerial
    var clients = []
    try { clients = JSON.parse(String(payload || "")) } catch (e) { clients = [] }
    if (serial !== root.pendingFocusSerial) return
    var address = InboxModel.focusAddress(clients, {
      app: root.pendingFocusApp,
      summary: root.pendingFocusSummary,
    })
    if (!address) return
    Quickshell.execDetached([
      "hyprctl", "dispatch",
      "hl.dsp.focus({ window = \"address:" + address + "\" })",
    ])
  }

  function removePath(path) {
    for (var i = rowsModel.count - 1; i >= 0; i--) {
      if (rowsModel.get(i).path === path) rowsModel.remove(i, 1)
    }
  }

  function deleteHistory(path) {
    if (!root.isHistoryFile(path)) return
    var next = {}
    var pending = root.pendingDelete
    for (var key in pending) {
      if (Object.prototype.hasOwnProperty.call(pending, key)) next[key] = true
    }
    next[path] = true
    root.pendingDelete = next
    Quickshell.execDetached(["rm", "-f", "--", path])
    Qt.callLater(function() { root.removePath(path) })
  }

  function applyDnd(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      root.dnd = !!(parsed && parsed.dnd === true)
    } catch (e) {}
  }

  function toggleDnd() {
    root.dnd = !root.dnd
    Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"])
    wiggle.restart()
  }

  function clearHistory() {
    var paths = []
    for (var i = 0; i < rowsModel.count; i++) {
      var path = String(rowsModel.get(i).path || "")
      if (root.isHistoryFile(path)) paths.push(path)
    }
    rowsModel.clear()
    if (paths.length > 0) Quickshell.execDetached(["rm", "-f", "--"].concat(paths))
    Quickshell.execDetached(["omarchy-shell", "notifications", "clear"])
  }

  ListModel { id: rowsModel }

  FileView {
    id: dndFile
    path: root.dndPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyDnd(text())
    onFileChanged: reload()
  }

  Timer {
    id: readTimer
    interval: 80
    repeat: false
    onTriggered: root.startRead()
  }

  Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: root.scheduleRead()
  }

  Process {
    id: watchProc
    running: true
    command: ["bash", "-c", root.watchScript, "--", root.historyDir]
    stdout: SplitParser {
      onRead: function(line) { root.scheduleRead() }
    }
  }

  Process {
    id: focusProc
    running: false
    stdout: StdioCollector {
      id: focusOut
      waitForEnd: true
      onStreamFinished: root.finishFocus(text)
    }
    onExited: {
      if (root.focusQueued) {
        root.focusQueued = false
        Qt.callLater(function() { root.startFocus() })
      }
    }
  }

  Process {
    id: readProc
    running: false
    stdout: StdioCollector {
      id: readOut
      waitForEnd: true
      onStreamFinished: root.finishRead(text)
    }
    onExited: {
      root.finishRead(readOut.text)
      if (root.readQueued) {
        root.readQueued = false
        Qt.callLater(function() { root.startRead() })
      }
    }
  }

  Component.onCompleted: root.scheduleRead()

  Item {
    id: frame
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    anchors.bottomMargin: 12
    // The column is already inset with the meter bank. Another top margin drops 通知 below the percentages.
    anchors.topMargin: 0

    Item {
      id: header
      width: parent.width
      height: 38

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
          text: "通知"
          font.family: Style.font.family
          font.pixelSize: 18
          font.bold: true
          color: root.fgBright
          anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          height: 20
          width: Math.max(20, countText.implicitWidth + 12)
          radius: 10
          color: root.sel
          Text {
            id: countText
            anchors.centerIn: parent
            text: rowsModel.count
            font.family: Style.font.family
            font.pixelSize: 12
            font.bold: true
            color: root.fgDim
          }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
          id: dndButton
          width: 36
          height: 36
          radius: 18
          color: root.dnd ? root.warnColor : root.bgLight
          scale: dndHit.pressed ? 0.96 : 1
          Behavior on color { ColorAnimation { duration: 200 } }
          Behavior on scale { NumberAnimation { duration: 100 } }
          Text {
            id: bell
            anchors.centerIn: parent
            text: root.dnd ? "\uf1f6" : "\uf0f3"
            font.family: Style.font.family
            font.pixelSize: 17
            color: root.fgBright
            transformOrigin: Item.Center
          }
          SequentialAnimation {
            id: wiggle
            NumberAnimation { target: bell; property: "rotation"; to: -18; duration: 70 }
            NumberAnimation { target: bell; property: "rotation"; to: 14; duration: 90 }
            NumberAnimation { target: bell; property: "rotation"; to: -8; duration: 90 }
            NumberAnimation { target: bell; property: "rotation"; to: 0; duration: 110 }
          }
          MouseArea {
            id: dndHit
            anchors.fill: parent
            anchors.margins: -6
            onClicked: root.toggleDnd()
          }
        }

        Rectangle {
          id: clearButton
          width: 36
          height: 36
          radius: 18
          color: root.bgLight
          opacity: rowsModel.count > 0 ? 1 : 0.35
          scale: clearHit.pressed ? 0.96 : 1
          Behavior on scale { NumberAnimation { duration: 100 } }
          Text {
            anchors.centerIn: parent
            text: "\uf1f8"
            font.family: Style.font.family
            font.pixelSize: 15
            color: root.fgBright
          }
          MouseArea {
            id: clearHit
            anchors.fill: parent
            anchors.margins: -6
            enabled: rowsModel.count > 0
            onClicked: root.clearHistory()
          }
        }

        Rectangle {
          width: 36
          height: 36
          radius: 18
          color: root.bgLight
          scale: settingsHit.pressed ? 0.96 : 1
          Behavior on scale { NumberAnimation { duration: 100 } }
          Text {
            id: gear
            anchors.centerIn: parent
            text: "\uf013"
            font.family: Style.font.family
            font.pixelSize: 17
            color: root.fgBright
            transformOrigin: Item.Center
            Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
          }
          MouseArea {
            id: settingsHit
            anchors.fill: parent
            anchors.margins: -6
            onClicked: {
              gear.rotation += 90
              root.settingsRequested()
            }
          }
        }
      }
    }

    Item {
      id: body
      y: header.height + 6
      width: parent.width
      height: parent.height - y

      Column {
        visible: rowsModel.count === 0
        anchors.centerIn: parent
        spacing: 8
        opacity: 0.7
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "\uf0f3"
          font.family: Style.font.family
          font.pixelSize: 34
          color: Color.muted
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "没有新通知"
          font.family: Style.font.family
          font.pixelSize: 15
          color: Color.muted
        }
      }

      ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: rowsModel
        boundsBehavior: Flickable.StopAtBounds
        spacing: 0

        add: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 280 }
            NumberAnimation { property: "x"; from: 60; to: 0; duration: 380; easing.type: Easing.OutCubic }
          }
        }
        populate: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 280 }
            NumberAnimation { property: "x"; from: 60; to: 0; duration: 380; easing.type: Easing.OutCubic }
          }
        }
        remove: Transition {
          ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 180 }
            NumberAnimation { property: "x"; to: -list.width; duration: 220; easing.type: Easing.InCubic }
          }
        }
        displaced: Transition {
          NumberAnimation { properties: "y"; duration: 280; easing.type: Easing.OutCubic }
        }

        delegate: Item {
          id: note
          required property int index
          required property var model
          width: list.width
          height: 84
          clip: true

          Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 12
            color: root.dangerColor
            opacity: Math.min(1, Math.max(0, -card.x / Math.max(1, note.width * 0.4)))
            Text {
              anchors.right: parent.right
              anchors.rightMargin: 20
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf1f8"
              font.family: Style.font.family
              font.pixelSize: 20
              color: root.fgBright
            }
          }

          Item {
            id: card
            width: parent.width
            height: parent.height
            opacity: Math.max(0, 1 + card.x / Math.max(1, note.width * 1.4))
            scale: gesture.pressed && !gesture.drag.active ? 0.96 : 1
            transformOrigin: Item.Center
            Behavior on x {
              enabled: !gesture.drag.active
              NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on scale { NumberAnimation { duration: 110 } }

            Rectangle {
              anchors.fill: parent
              anchors.topMargin: 3
              anchors.bottomMargin: 3
              radius: 12
              color: gesture.pressed ? root.bgLight : "transparent"
              Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
              id: tile
              x: 8
              y: 14
              width: 40
              height: 40
              radius: 11
              clip: true
              color: note.model.iconKind === "initial" ? note.model.iconColor : root.sel
              Text {
                anchors.centerIn: parent
                visible: noteIcon.status !== Image.Ready
                text: {
                  if (note.model.iconKind === "initial" && note.model.iconLetter) return note.model.iconLetter
                  var app = String(note.model.app || "")
                  return app.length > 0 ? app.charAt(0).toUpperCase() : "?"
                }
                font.family: Style.font.family
                font.pixelSize: 19
                font.bold: true
                color: root.bgDark
              }
              Image {
                id: noteIcon
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 80
                sourceSize.height: 80
                source: {
                  var themed = root.themeIconUrl(note.model.iconNames)
                  if (themed) return themed
                  if (note.model.iconKind === "file" && note.model.iconPath)
                    return Util.fileUrl(note.model.iconPath)
                  if (note.model.iconKind === "theme-name" && note.model.iconName)
                    return Quickshell.iconPath(note.model.iconName, true) || ""
                  return ""
                }
              }
            }

            Column {
              x: 60
              y: 10
              width: parent.width - 70
              spacing: 2
              Item {
                width: parent.width
                height: 16
                Text {
                  text: note.model.app
                  font.family: Style.font.family
                  font.pixelSize: 12
                  font.bold: true
                  color: root.fgDim
                  width: parent.width - whenRow.width - 8
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }
                Row {
                  id: whenRow
                  anchors.right: parent.right
                  spacing: 6
                  Rectangle {
                    visible: !!note.model.fresh
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 7
                    radius: 4
                    color: Color.accent
                  }
                  Text {
                    text: note.model.timeLabel
                    font.family: Style.font.family
                    font.pixelSize: 12
                    color: Color.muted
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
              Text {
                width: parent.width
                text: note.model.summary
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 16
                font.bold: true
                color: root.fgBright
              }
              Text {
                width: parent.width
                text: note.model.body
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: 14
                color: Color.foreground
                opacity: 0.85
              }
            }

            Rectangle {
              x: 60
              anchors.bottom: parent.bottom
              width: parent.width - 60
              height: 1
              color: root.sel
              opacity: 0.6
            }
          }

          MouseArea {
            id: gesture
            anchors.fill: parent
            drag.target: card
            drag.axis: Drag.XAxis
            drag.minimumX: -note.width
            drag.maximumX: 0
            drag.threshold: 12
            preventStealing: false
            onReleased: {
              var decision = InboxModel.swipeDecision(card.x, note.width)
              if (decision === "commit") root.deleteHistory(note.model.path)
              else {
                if (Math.abs(card.x) < 8) root.activate(note.model)
                card.x = 0
              }
            }
          }
        }
      }
    }
  }
}
