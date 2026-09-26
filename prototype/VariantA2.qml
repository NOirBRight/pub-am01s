// PROTOTYPE A2 — A's layout, refined: segmented LED meters without cards,
// count-up numbers, staggered entrance, Detail that grows out of the tapped
// column, and an animated notification list (slide-in, swipe, collapse).
import QtQuick
import Quickshell

Item {
  id: v
  property var r

  // ---- expand / collapse choreography ----
  property real originX: 300
  property string lastId: r.expanded
  property real progress: r.expanded ? 1 : 0
  Behavior on progress { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
  Connections { target: v.r; function onExpandedChanged() { if (v.r.expanded) v.lastId = v.r.expanded } }

  readonly property int maxW: Math.round(width * 0.615)
  function hue(name) {
    const pal = [r.t.accent, "#2DD5B7", "#D2689C", "#a2734b", "#81B8A8", "#549e6a"]
    let h = 0; for (const ch of String(name)) h = (h * 31 + ch.charCodeAt(0)) >>> 0
    return pal[h % pal.length]
  }
  function iconSrc(a) {
    if (!a) return ""
    if (a.startsWith("file:") || a.startsWith("/")) return a
    return Quickshell.iconPath(a, true)
  }

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.lighter(v.r.t.bg, 1.12) }
      GradientStop { position: 1; color: v.r.t.bgDark }
    }
  }

  // ================= meters =================
  Item {
    id: meters
    readonly property int n: Math.max(1, r.providers.length)
    readonly property int pad: 20
    readonly property int slots: r.providers.reduce((s, p) => s + Math.max(1, (p.windows || []).length), 0) || 1
    readonly property bool wide: (v.maxW - n * pad) / slots >= 56
    readonly property int natural: wide ? Math.min(v.maxW, slots * 84 + n * pad) : v.maxW
    x: 10; y: 12; height: parent.height - 24
    width: r.expanded ? v.maxW : natural
    property bool settled: false
    Timer { interval: 500; running: true; onTriggered: meters.settled = true }
    Behavior on width { enabled: meters.settled; NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

    Row {
      id: cols
      height: parent.height
      opacity: 1 - v.progress
      scale: 1 - 0.05 * v.progress
      visible: opacity > 0.01
      Repeater {
        model: r.providers
        delegate: Item {
          id: col
          required property var modelData
          required property int index
          readonly property int mine: Math.max(1, (modelData.windows || []).length)
          readonly property bool err: !!modelData.error
          width: meters.wide ? (meters.natural - meters.n * meters.pad) * mine / meters.slots + meters.pad
                             : meters.natural / meters.n
          height: cols.height

          Rectangle { visible: col.index > 0; width: 1; y: parent.height * 0.1; height: parent.height * 0.8; color: v.r.t.sel; opacity: 0.7 }

          Item {
            id: body
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
            opacity: 0
            scale: hit.pressed ? 0.96 : 1
            Behavior on scale { NumberAnimation { duration: 110 } }
            transform: Translate { id: lift; y: 14 }
            SequentialAnimation {
              running: true
              PauseAnimation { duration: col.index * 70 }
              ParallelAnimation {
                NumberAnimation { target: body; property: "opacity"; to: 1; duration: 320 }
                NumberAnimation { target: lift; property: "y"; to: 0; duration: 420; easing.type: Easing.OutCubic }
              }
            }

            // ---- wide: header + every Quota Window ----
            Item {
              anchors.fill: parent; visible: meters.wide
              Row {
                id: head; y: 2; spacing: 7; width: parent.width; clip: true
                ProviderIcon { width: 18; height: 18; source: v.r.icon(col.modelData.id); tint: v.r.t.fgBright }
                Text { width: Math.min(implicitWidth, head.width - 25); elide: Text.ElideRight
                  text: col.width < 120 ? v.r.shortName(col.modelData) : col.modelData.name
                  font.family: v.r.t.font; font.pixelSize: 14; font.bold: true; color: v.r.t.fgBright }
                Text { visible: col.width >= 170; anchors.baseline: parent.children[1].baseline; text: col.modelData.plan || ""
                  font.pixelSize: 12; color: v.r.t.muted }
              }
              Text { visible: col.err; y: 40; width: parent.width; wrapMode: Text.Wrap; text: "未登录"; font.pixelSize: 14; color: v.r.t.danger }
              Row {
                id: subs; visible: !col.err
                y: 34; height: parent.height - 34; width: parent.width
                readonly property var ws: col.modelData.windows || []
                Repeater {
                  model: subs.ws
                  delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    width: subs.width / subs.ws.length; height: subs.height
                    CountText { anchors.horizontalCenter: parent.horizontalCenter; y: 4
                      value: slot.modelData.remaining; delay: col.index * 70 + 120 + slot.index * 60
                      size: slot.modelData.primary ? 24 : 18; family: v.r.t.font
                      color: slot.modelData.primary ? v.r.t.fgBright : v.r.t.fg }
                    SegBar { anchors.horizontalCenter: parent.horizontalCenter; y: 40; width: 20; height: parent.height - 40 - 40
                      value: slot.modelData.remaining ?? 0; delay: col.index * 70 + 120 + slot.index * 60
                      color: v.r.level(slot.modelData.remaining); track: v.r.t.sel
                      pulse: (slot.modelData.remaining ?? 1) <= 0.05 }
                    Column { anchors.bottom: parent.bottom; width: parent.width; spacing: 1
                      Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: v.r.short(slot.modelData)
                        font.family: v.r.t.font; font.pixelSize: 12; font.bold: slot.modelData.primary; color: slot.modelData.primary ? v.r.t.fgBright : v.r.t.fg }
                      Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: "\uf021 " + (slot.modelData.resetLabel || "").replace("Resets in ", "").replace(/^(\d+d) \d+h$/, "$1")
                        font.family: v.r.t.font; font.pixelSize: 11; color: v.r.t.muted } }
                  }
                }
              }
            }

            // ---- compact: Primary Window only ----
            Item {
              anchors.fill: parent; visible: !meters.wide
              CountText { anchors.horizontalCenter: parent.horizontalCenter; y: 2; value: col.err ? null : col.modelData.remaining
                delay: col.index * 70 + 120; size: 20; family: v.r.t.font; color: col.err ? v.r.t.muted : v.r.t.fgBright }
              SegBar { anchors.horizontalCenter: parent.horizontalCenter; y: 36; width: 20; height: parent.height - 36 - 50
                value: col.err ? 0 : (col.modelData.remaining ?? 0); delay: col.index * 70 + 120
                color: v.r.level(col.modelData.remaining); track: v.r.t.sel
                pulse: !col.err && (col.modelData.remaining ?? 1) <= 0.05 }
              ProviderIcon { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 20
                width: 20; height: 20; source: v.r.icon(col.modelData.id); tint: col.err ? v.r.t.muted : v.r.t.fgBright }
              Text { anchors.bottom: parent.bottom; width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                text: v.r.shortName(col.modelData); font.family: v.r.t.font; font.pixelSize: 11; color: col.err ? v.r.t.danger : v.r.t.fgDim }
            }
          }

          MouseArea {
            id: hit; anchors.fill: parent
            onClicked: { v.originX = col.x + col.width / 2; v.r.toggle(col.modelData.id) }
          }
        }
      }
    }

    // ================= Detail =================
    Item {
      id: detail
      readonly property var p: r.providers.find(x => x.id === v.lastId) ?? null
      anchors.fill: parent
      visible: v.progress > 0.01 && !!p
      opacity: v.progress
      transform: Scale { origin.x: v.originX; origin.y: detail.height / 2; xScale: 0.55 + 0.45 * v.progress; yScale: 0.9 + 0.1 * v.progress }

      Rectangle { anchors.fill: parent; radius: 14; color: v.r.t.bgLight; opacity: 0.55 }
      MouseArea { anchors.fill: parent; onClicked: v.r.toggle(v.r.expanded) }

      Row {
        x: 20; y: 16; spacing: 12
        ProviderIcon { width: 30; height: 30; source: detail.p ? v.r.icon(detail.p.id) : ""; tint: v.r.t.fgBright }
        Text { anchors.verticalCenter: parent.verticalCenter; text: detail.p ? detail.p.name : ""; font.family: v.r.t.font; font.pixelSize: 24; font.bold: true; color: v.r.t.fgBright }
        Rectangle { visible: !!(detail.p && detail.p.plan); anchors.verticalCenter: parent.verticalCenter; height: 24; width: planT.implicitWidth + 18; radius: 12; color: v.r.t.sel
          Text { id: planT; anchors.centerIn: parent; text: detail.p ? detail.p.plan || "" : ""; font.pixelSize: 14; font.bold: true; color: v.r.t.fgDim } }
      }
      Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 14; y: 12; width: 38; height: 38; radius: 19; color: v.r.t.sel
        Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 18; color: v.r.t.fgBright }
      }
      Text {
        visible: !!(detail.p && detail.p.error); x: 20; y: 74; width: parent.width - 40; wrapMode: Text.Wrap
        text: "未登录或拉取失败（" + (detail.p ? detail.p.error : "") + "）\n在主屏「PUB 设置」里重新登录。"
        font.pixelSize: 20; lineHeight: 1.3; color: v.r.t.danger
      }
      Row {
        id: big
        visible: !!(detail.p && !detail.p.error)
        readonly property var ws: detail.p ? detail.p.windows || [] : []
        readonly property int slotW: Math.min(170, (detail.width - 40) / Math.max(1, ws.length))
        x: (detail.width - slotW * ws.length) / 2; y: 64; height: detail.height - 64 - 16
        Repeater {
          model: v.progress > 0.5 ? big.ws : []      // re-create on open so the bars refill
          delegate: Item {
            id: bs
            required property var modelData
            required property int index
            width: big.slotW; height: big.height
            CountText { anchors.horizontalCenter: parent.horizontalCenter; value: bs.modelData.remaining; delay: bs.index * 80
              size: bs.modelData.primary ? 34 : 28; family: v.r.t.font; color: bs.modelData.primary ? v.r.t.fgBright : v.r.t.fg }
            SegBar { anchors.horizontalCenter: parent.horizontalCenter; y: 48; width: 34; height: parent.height - 48 - 54; seg: 7
              value: bs.modelData.remaining ?? 0; delay: bs.index * 80; color: v.r.level(bs.modelData.remaining); track: v.r.t.sel
              pulse: (bs.modelData.remaining ?? 1) <= 0.05 }
            Column { anchors.bottom: parent.bottom; width: parent.width; spacing: 3
              Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: bs.modelData.label
                font.family: v.r.t.font; font.pixelSize: 17; font.bold: bs.modelData.primary; color: v.r.t.fgBright }
              Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                text: "\uf021 " + (bs.modelData.resetLabel || "").replace("Resets in ", ""); font.family: v.r.t.font; font.pixelSize: 15; color: v.r.t.fgDim } }
          }
        }
      }
    }
  }

  // ================= inbox =================
  Rectangle { x: meters.x + meters.width + 10; y: 22; width: 1; height: parent.height - 44; color: v.r.t.sel }

  ListModel { id: noteModel }
  function syncNotes() {
    const want = r.visibleNotes()
    const keep = {}; for (const n of want) keep[n.file] = true
    for (let i = noteModel.count - 1; i >= 0; i--) if (!keep[noteModel.get(i).file]) noteModel.remove(i)
    for (let i = 0; i < want.length; i++) {
      const n = want[i]
      if (i < noteModel.count && noteModel.get(i).file === n.file) continue
      noteModel.insert(i, { file: n.file, app: n.app || "", summary: n.summary || "", body: n.body || "",
        appIcon: n.appIcon || "", execArgv: n.execArgv || "", urgency: n.urgency || 1, timestamp: n.timestamp || 0 })
    }
  }
  Component.onCompleted: syncNotes()
  Connections { target: v.r; function onNotesChanged() { v.syncNotes() } function onDismissedChanged() { v.syncNotes() } }

  Item {
    id: inbox
    x: meters.x + meters.width + 22; y: 12; width: parent.width - x - 12; height: parent.height - 24

    Item {
      id: ihead; width: parent.width; height: 38
      Row {
        anchors.verticalCenter: parent.verticalCenter; spacing: 8
        Text { text: "通知"; font.pixelSize: 18; font.bold: true; color: v.r.t.fgBright }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 20; width: Math.max(20, cnt.implicitWidth + 12); radius: 10; color: v.r.t.sel
          Text { id: cnt; anchors.centerIn: parent; text: noteModel.count; font.family: v.r.t.font; font.pixelSize: 12; font.bold: true; color: v.r.t.fgDim } }
      }
      Row {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 10
        Rectangle {
          id: dndBtn; width: 36; height: 36; radius: 18
          color: v.r.dnd ? v.r.t.warn : v.r.t.bgLight
          Behavior on color { ColorAnimation { duration: 200 } }
          scale: dndHit.pressed ? 0.88 : 1
          Behavior on scale { NumberAnimation { duration: 100 } }
          Text { id: bell; anchors.centerIn: parent; text: v.r.dnd ? "" : ""; font.family: v.r.t.font; font.pixelSize: 17; color: v.r.t.fgBright }
          SequentialAnimation {
            id: wiggle
            RotationAnimation { target: bell; to: -18; duration: 70 }
            RotationAnimation { target: bell; to: 14; duration: 90 }
            RotationAnimation { target: bell; to: -8; duration: 90 }
            RotationAnimation { target: bell; to: 0; duration: 110 }
          }
          MouseArea { id: dndHit; anchors.fill: parent; anchors.margins: -6; onClicked: { v.r.toggleDnd(); wiggle.restart() } }
        }
        Rectangle {
          width: 36; height: 36; radius: 18; color: v.r.t.bgLight
          scale: setHit.pressed ? 0.88 : 1
          Behavior on scale { NumberAnimation { duration: 100 } }
          Text { id: gear; anchors.centerIn: parent; text: ""; font.family: v.r.t.font; font.pixelSize: 17; color: v.r.t.fgBright
            Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
          MouseArea { id: setHit; anchors.fill: parent; anchors.margins: -6; onClicked: { gear.rotation += 90; v.r.openSettings() } }
        }
      }
    }

    Column {
      visible: noteModel.count === 0; anchors.centerIn: parent; spacing: 8; opacity: 0.7
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: ""; font.family: v.r.t.font; font.pixelSize: 34; color: v.r.t.muted }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: "没有新通知"; font.pixelSize: 15; color: v.r.t.muted }
    }

    ListView {
      id: list
      y: ihead.height + 6; width: parent.width; height: parent.height - y; clip: true
      model: noteModel
      boundsBehavior: Flickable.DragOverBounds
      add: Transition { ParallelAnimation {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 280 }
        NumberAnimation { property: "x"; from: 60; to: 0; duration: 380; easing.type: Easing.OutCubic } } }
      remove: Transition { ParallelAnimation {
        NumberAnimation { property: "opacity"; to: 0; duration: 180 }
        NumberAnimation { property: "x"; to: -list.width; duration: 220; easing.type: Easing.InCubic } } }
      displaced: Transition { NumberAnimation { properties: "y"; duration: 280; easing.type: Easing.OutCubic } }

      delegate: Item {
        id: note
        required property int index
        required property var model
        readonly property bool fresh: Date.now() - model.timestamp < 10 * 60 * 1000
        width: list.width; height: 84

        Rectangle {
          anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3; radius: 12; color: v.r.t.danger
          opacity: Math.min(1, -card.x / 90)
          Text { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
            text: ""; font.family: v.r.t.font; font.pixelSize: 20; color: v.r.t.fgBright }
        }
        Item {
          id: card
          width: parent.width; height: parent.height
          opacity: 1 + card.x / (note.width * 1.4)
          Behavior on x { enabled: !drag.drag.active; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Rectangle { anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3; radius: 12
            color: drag.pressed ? v.r.t.bgLight : "transparent"; Behavior on color { ColorAnimation { duration: 120 } } }

          Rectangle {
            id: tile; x: 8; y: 14; width: 40; height: 40; radius: 11; clip: true
            color: v.hue(note.model.app)
            readonly property string src: v.iconSrc(note.model.appIcon)
            Text { anchors.centerIn: parent; visible: !tile.src || img.status !== Image.Ready
              text: (note.model.app || "?")[0].toUpperCase(); font.pixelSize: 19; font.bold: true; color: v.r.t.bgDark }
            Image { id: img; anchors.fill: parent; source: tile.src; sourceSize.width: 80; sourceSize.height: 80; fillMode: Image.PreserveAspectCrop; asynchronous: true }
          }
          Column {
            x: 60; y: 10; width: parent.width - 60 - 10; spacing: 2
            Item {
              width: parent.width; height: 16
              Text { text: note.model.app; font.pixelSize: 12; font.bold: true; color: v.r.t.fgDim; font.letterSpacing: 0.4 }
              Row { anchors.right: parent.right; spacing: 6
                Rectangle { visible: note.fresh; anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 4; color: v.r.t.accent }
                Text { text: v.r.ago(note.model.timestamp); font.family: v.r.t.font; font.pixelSize: 12; color: v.r.t.muted } }
            }
            Text { width: parent.width; text: note.model.summary || note.model.app; elide: Text.ElideRight; textFormat: Text.PlainText
              font.pixelSize: 16; font.bold: true; color: v.r.t.fgBright }
            Text { width: parent.width; text: note.model.body; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText
              font.pixelSize: 14; color: v.r.t.fg; opacity: 0.85 }
          }
          Rectangle { x: 60; anchors.bottom: parent.bottom; width: parent.width - 60; height: 1; color: v.r.t.sel; opacity: 0.6 }
        }
        MouseArea {
          id: drag
          anchors.fill: parent
          drag.target: card; drag.axis: Drag.XAxis; drag.minimumX: -note.width; drag.maximumX: 0; drag.threshold: 8
          onReleased: {
            const m = note.model
            if (card.x < -note.width * 0.3) v.r.dismiss({ file: m.file, app: m.app })
            else { if (Math.abs(card.x) < 6) v.r.openNote({ app: m.app, execArgv: m.execArgv }); card.x = 0 }
          }
        }
      }
    }
  }
}
