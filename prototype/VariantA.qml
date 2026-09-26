// PROTOTYPE A — Split: left 600px = vertical bar columns (one per Enabled
// Provider, like a VU meter); right 360px = notification inbox with DND +
// settings in its header. Tap a column → it widens in place into Detail.
import QtQuick

Item {
  id: v
  property var r
  Rectangle { anchors.fill: parent; color: r.t.bg }

  // ---- left: meters ----
  Item {
    id: meters
    // Every Quota Window gets an equal slot; a Provider is as wide as its windows.
    readonly property int n: Math.max(1, r.providers.length)
    readonly property int slots: r.providers.reduce((s, p) => s + Math.max(1, (p.windows || []).length), 0) || 1
    readonly property bool wide: !r.expanded && (590 - (n - 1) * 8 - n * 24) / slots >= 56
    x: 12; y: 10; height: parent.height - 50
    width: r.expanded ? 590 : wide ? Math.min(590, slots * 90 + (n - 1) * 8 + n * 24) : 590
    Text { text: "PLAN QUOTA"; font.family: r.t.font; font.pixelSize: 11; font.letterSpacing: 2; color: r.t.muted }
    Row {
      visible: !r.expanded
      y: 22; height: parent.height - 22; width: parent.width; spacing: 8
      Repeater {
        model: r.providers
        delegate: Item {
          id: col
          required property var modelData
          readonly property bool open: r.expanded === modelData.id
          readonly property int n: r.providers.length
          readonly property int others: r.expanded ? n - 1 : n
          readonly property int mine: Math.max(1, (modelData.windows || []).length)
          width: meters.wide ? (meters.width - (n - 1) * 8 - n * 24) * mine / meters.slots + 24
            : (meters.width - (n - 1) * 8) / n
          height: parent.height
          Behavior on width { NumberAnimation { duration: 160 } }
          Rectangle { anchors.fill: parent; radius: 10; color: col.open ? r.t.bgLight : r.t.bgDark }

          readonly property bool wide: meters.wide

          // wide column: header + one sub-bar per Quota Window
          Item {
            anchors.fill: parent; anchors.margins: 12; visible: col.wide; clip: true
            Row { id: wh; spacing: 6
              ProviderIcon { width: 22; height: 22; source: r.icon(col.modelData.id) }
              Text { width: Math.min(implicitWidth, col.width - 24 - 28); elide: Text.ElideRight; text: col.width < 120 ? r.shortName(col.modelData) : col.modelData.name; font.family: r.t.font; font.pixelSize: col.width < 120 ? 13 : 15; font.bold: true; color: r.t.fgBright }
              Text { visible: col.width >= 170; anchors.baseline: parent.children[1].baseline; text: col.modelData.plan || ""; font.pixelSize: 12; color: r.t.muted } }
            Row {
              id: subs; y: 34; width: parent.width; height: parent.height - 34; spacing: 10
              readonly property var ws: col.modelData.windows || []
              Repeater {
                model: subs.ws
                delegate: Item {
                  required property var modelData
                  width: (subs.width - (subs.ws.length - 1) * 10) / subs.ws.length; height: subs.height
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: r.pct(modelData.remaining); font.family: r.t.font; font.bold: true
                    font.pixelSize: modelData.primary ? 22 : 17; color: modelData.primary ? r.t.fgBright : r.t.fg }
                  Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 30; width: 22; height: parent.height - 30 - 38
                    radius: width / 2; color: r.t.sel
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: width / 2
                      height: parent.height * (modelData.remaining ?? 0); color: r.level(modelData.remaining) } }
                  Column { anchors.bottom: parent.bottom; width: parent.width
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: r.short(modelData); font.family: r.t.font; font.pixelSize: 12; color: r.t.fg }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "↻ " + (modelData.resetLabel || "").replace("Resets in ", "").replace(/^(\d+d) \d+h$/, "$1"); font.pixelSize: 11; color: r.t.muted } }
                }
              }
            }
          }

          // compact column
          Item {
            anchors.fill: parent; visible: !col.open && !col.wide
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 8
              text: col.modelData.error ? "!" : r.pct(col.modelData.remaining); font.family: r.t.font; font.bold: true
              font.pixelSize: r.expanded ? 11 : 20; color: col.modelData.error ? r.t.muted : r.t.fgBright }
            Rectangle {
              id: track; anchors.horizontalCenter: parent.horizontalCenter; y: r.expanded ? 28 : 40
              width: r.expanded ? 10 : 22; height: parent.height - y - 58; radius: width / 2; color: r.t.sel
              Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: width / 2
                height: parent.height * (col.modelData.remaining ?? 0); color: r.level(col.modelData.remaining) }
            }
            Text { visible: !r.expanded; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; width: parent.width - 6; anchors.horizontalCenter: parent.horizontalCenter
              horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: r.shortName(col.modelData); font.family: r.t.font; font.pixelSize: 10; color: r.t.fgDim }
            ProviderIcon { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: r.expanded ? 10 : 22
              width: 24; height: 24; source: r.icon(col.modelData.id); sourceSize.width: 48; sourceSize.height: 48
              opacity: col.modelData.error ? 0.4 : 1 }
          }

          // expanded Detail
          Column {
            visible: col.open; anchors.fill: parent; anchors.margins: 12; spacing: 8
            Row { spacing: 8
              ProviderIcon { width: 24; height: 24; source: r.icon(col.modelData.id); sourceSize.width: 48; sourceSize.height: 48 }
              Text { text: col.modelData.name + (col.modelData.plan ? "  ·  " + col.modelData.plan : ""); font.family: r.t.font; font.pixelSize: 16; font.bold: true; color: r.t.fgBright }
              Text { text: col.modelData.error || ""; font.pixelSize: 13; color: r.t.danger } }
            Repeater {
              model: col.modelData.windows || []
              delegate: Column {
                required property var modelData
                width: parent.width; spacing: 3
                Row { width: parent.width
                  Text { width: parent.width - p.width; text: modelData.label; font.family: r.t.font; font.pixelSize: 13; color: r.t.fg }
                  Text { id: p; text: r.pct(modelData.remaining); font.family: r.t.font; font.pixelSize: 13; font.bold: true; color: r.t.fgBright } }
                Rectangle { width: parent.width; height: 8; radius: 4; color: r.t.sel
                  Rectangle { width: parent.width * (modelData.remaining ?? 0); height: 8; radius: 4; color: r.level(modelData.remaining) } }
                Text { text: modelData.resetLabel || ""; font.pixelSize: 11; color: r.t.muted }
              }
            }
          }
          MouseArea { anchors.fill: parent; onClicked: r.toggle(col.modelData.id) }
        }
      }
    }
  }

  // ---- Detail: one Provider fills the whole meters area ----
  Rectangle {
    id: detail
    readonly property var p: r.providers.find(x => x.id === r.expanded) ?? null
    visible: !!p
    x: meters.x; y: meters.y; width: meters.width; height: meters.height
    radius: 12; color: r.t.bgLight
    MouseArea { anchors.fill: parent; onClicked: r.toggle(r.expanded) }
    Row {
      x: 18; y: 14; spacing: 12
      ProviderIcon { width: 32; height: 32; source: detail.p ? r.icon(detail.p.id) : "" }
      Text { anchors.verticalCenter: parent.verticalCenter; text: detail.p ? detail.p.name : ""; font.family: r.t.font; font.pixelSize: 24; font.bold: true; color: r.t.fgBright }
      Text { anchors.verticalCenter: parent.verticalCenter; text: detail.p ? (detail.p.plan || "") : ""; font.pixelSize: 17; color: r.t.fgDim }
    }
    Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 12; text: "✕"; font.pixelSize: 28; color: r.t.fg }
    Text {
      visible: !!(detail.p && detail.p.error); x: 18; y: 70; width: parent.width - 36; wrapMode: Text.Wrap
      text: detail.p && detail.p.error ? "未登录或拉取失败：" + detail.p.error + "\n在主屏「PUB 设置」里重新登录。" : ""
      font.pixelSize: 20; color: r.t.danger
    }
    Row {
      id: big
      visible: !!(detail.p && !detail.p.error)
      readonly property var ws: detail.p ? detail.p.windows || [] : []
      x: Math.max(18, (parent.width - implicitWidth) / 2); y: 62; height: parent.height - 62 - 14; spacing: 16
      Repeater {
        model: big.ws
        delegate: Item {
          required property var modelData
          width: Math.min(170, (detail.width - 36 - (big.ws.length - 1) * 16) / Math.max(1, big.ws.length)); height: big.height
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: r.pct(modelData.remaining); font.family: r.t.font; font.bold: true
            font.pixelSize: modelData.primary ? 34 : 28; color: modelData.primary ? r.t.fgBright : r.t.fg }
          Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 44; width: 30; height: parent.height - 44 - 52; radius: 15; color: r.t.sel
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 15; height: parent.height * (modelData.remaining ?? 0); color: r.level(modelData.remaining) } }
          Column { anchors.bottom: parent.bottom; width: parent.width; spacing: 2
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.label; font.family: r.t.font; font.pixelSize: 17; font.bold: modelData.primary; color: r.t.fgBright }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: "↻ " + (modelData.resetLabel || "").replace("Resets in ", ""); font.pixelSize: 15; color: r.t.fgDim } }
        }
      }
    }
  }

  // ---- right: inbox ----
  Rectangle { x: meters.width + 22; y: 10; width: 1; height: parent.height - 50; color: r.t.sel }
  Item {
    x: meters.width + 32; y: 10; width: 960 - meters.width - 44; height: parent.height - 50
    Row {
      id: head; width: parent.width; height: 22
      Text { width: parent.width - btns.width; text: "NOTIFICATIONS  " + r.visibleNotes().length; font.family: r.t.font; font.pixelSize: 13; font.letterSpacing: 2; color: r.t.muted }
      Row { id: btns; spacing: 18
        Text { text: r.dnd ? "" : ""; font.family: r.t.font; font.pixelSize: 20; color: r.dnd ? r.t.warn : r.t.fg
          MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: r.toggleDnd() } }
        Text { text: ""; font.family: r.t.font; font.pixelSize: 20; color: r.t.fg
          MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: r.openSettings() } } }
    }
    ListView {
      y: 34; width: parent.width; height: parent.height - 34; clip: true; spacing: 8
      model: r.visibleNotes()
      delegate: NoteRow { required property var modelData; r: v.r; n: modelData; width: ListView.view.width }
    }
  }
}
