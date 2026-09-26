// PROTOTYPE B — Rows + ticker: top 2/3 = two-column grid of horizontal
// Meter rows (icon · name · bar · % · reset); tap a row → a Detail sheet
// covers the grid. Bottom 1/3 = one big notification at a time (swipe to
// dismiss → the next one), with DND / settings as big touch buttons.
import QtQuick

Item {
  id: v
  property var r
  Rectangle { anchors.fill: parent; color: r.t.bg }

  Grid {
    id: grid
    x: 12; y: 12; width: parent.width - 24; columns: 2; columnSpacing: 12; rowSpacing: 8
    Repeater {
      model: r.providers
      delegate: Rectangle {
        id: cell
        required property var modelData
        readonly property var w: r.primary(modelData)
        width: (grid.width - 12) / 2; height: 54; radius: 10; color: r.t.bgDark
        ProviderIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26
          source: r.icon(cell.modelData.id); sourceSize.width: 52; sourceSize.height: 52; opacity: cell.modelData.error ? 0.4 : 1 }
        Column {
          x: 50; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 50 - 72; spacing: 5
          Row { width: parent.width
            Text { width: parent.width - rs.width; text: cell.modelData.name; font.family: r.t.font; font.pixelSize: 13; font.bold: true; color: r.t.fgBright; elide: Text.ElideRight }
            Text { id: rs; text: cell.modelData.error || (cell.w ? cell.w.resetLabel || "" : ""); font.pixelSize: 11; color: cell.modelData.error ? r.t.danger : r.t.muted } }
          Rectangle { width: parent.width; height: 8; radius: 4; color: r.t.sel
            Rectangle { width: parent.width * (cell.modelData.remaining ?? 0); height: 8; radius: 4; color: r.level(cell.modelData.remaining) } }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
          text: cell.modelData.error ? "—" : r.pct(cell.modelData.remaining); font.family: r.t.font; font.pixelSize: 22; font.bold: true; color: r.t.fgBright }
        MouseArea { anchors.fill: parent; onClicked: r.toggle(cell.modelData.id) }
      }
    }
  }

  // Detail sheet over the grid
  Rectangle {
    readonly property var p: r.providers.find(x => x.id === r.expanded)
    visible: !!p; x: 12; y: 12; width: parent.width - 24; height: 262; radius: 12; color: r.t.bgLight
    Row { x: 16; y: 14; spacing: 10
      ProviderIcon { width: 30; height: 30; source: parent.parent.p ? r.icon(parent.parent.p.id) : ""; sourceSize.width: 60; sourceSize.height: 60 }
      Text { text: parent.parent.p ? parent.parent.p.name + "  ·  " + (parent.parent.p.plan || "") : ""; font.family: r.t.font; font.pixelSize: 20; font.bold: true; color: r.t.fgBright } }
    Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 16; text: "✕"; font.pixelSize: 20; color: r.t.fg }
    Flow {
      x: 16; y: 60; width: parent.width - 32; spacing: 14
      Repeater {
        model: parent.parent.p ? parent.parent.p.windows || [] : []
        delegate: Column {
          required property var modelData
          width: 280; spacing: 4
          Text { text: modelData.label + (modelData.primary ? " ★" : "") + "   " + r.pct(modelData.remaining); font.family: r.t.font; font.pixelSize: 15; color: r.t.fgBright }
          Rectangle { width: parent.width; height: 10; radius: 5; color: r.t.sel
            Rectangle { width: parent.width * (modelData.remaining ?? 0); height: 10; radius: 5; color: r.level(modelData.remaining) } }
          Text { text: modelData.resetLabel || ""; font.pixelSize: 12; color: r.t.muted }
        }
      }
    }
    MouseArea { anchors.fill: parent; onClicked: r.toggle(r.expanded) }
  }

  // ticker
  Item {
    x: 12; y: 284; width: parent.width - 24; height: 110 - 36
    readonly property var list: r.visibleNotes()
    NoteRow { visible: parent.list.length > 0; r: v.r; n: parent.list[0] || ({}); big: true
      width: parent.width - 150; height: parent.height }
    Text { visible: parent.list.length === 0; anchors.verticalCenter: parent.verticalCenter; x: 10; text: "没有通知"; font.pixelSize: 14; color: r.t.muted }
    Text { x: parent.width - 150 - 44; y: -18; text: parent.list.length ? "1 / " + parent.list.length : ""; font.family: r.t.font; font.pixelSize: 11; color: r.t.muted }
    Row {
      anchors.right: parent.right; height: parent.height; spacing: 8
      Rectangle { width: 66; height: parent.height; radius: 10; color: r.dnd ? r.t.warn : r.t.bgDark
        Text { anchors.centerIn: parent; text: r.dnd ? "" : ""; font.family: r.t.font; font.pixelSize: 24; color: r.t.fgBright }
        MouseArea { anchors.fill: parent; onClicked: r.toggleDnd() } }
      Rectangle { width: 66; height: parent.height; radius: 10; color: r.t.bgDark
        Text { anchors.centerIn: parent; text: ""; font.family: r.t.font; font.pixelSize: 24; color: r.t.fgBright }
        MouseArea { anchors.fill: parent; onClicked: r.openSettings() } }
    }
  }
}
