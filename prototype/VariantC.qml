// PROTOTYPE C — Rail + focus + inbox: left rail = Provider icons with a
// Remaining ring (tap to focus; settings/DND at the rail foot); centre =
// the focused Provider's Detail always open (default: the lowest Remaining);
// right = dense one-line notification list.
import QtQuick

Item {
  id: v
  property var r
  Rectangle { anchors.fill: parent; color: r.t.bg }

  readonly property var ok: r.providers.filter(p => !p.error)
  readonly property var picked: r.providers.find(p => p.id === r.expanded)
    ?? ok.slice().sort((a, b) => (a.remaining ?? 1) - (b.remaining ?? 1))[0] ?? r.providers[0]

  // rail
  Rectangle { x: 0; y: 0; width: 76; height: parent.height; color: r.t.bgDark }
  Column {
    x: 10; y: 8; spacing: 4
    Repeater {
      model: r.providers
      delegate: Item {
        id: it
        required property var modelData
        width: 56; height: 46
        Rectangle { anchors.fill: parent; radius: 10; color: v.picked && v.picked.id === it.modelData.id ? r.t.sel : "transparent" }
        Canvas {
          anchors.centerIn: parent; width: 40; height: 40
          property real frac: it.modelData.remaining ?? 0
          property color c: r.level(it.modelData.remaining)
          onFracChanged: requestPaint()
          onPaint: {
            const g = getContext("2d"); g.reset(); g.lineWidth = 4
            g.strokeStyle = r.t.sel; g.beginPath(); g.arc(20, 20, 17, 0, Math.PI * 2); g.stroke()
            g.strokeStyle = c; g.beginPath(); g.arc(20, 20, 17, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac); g.stroke()
          }
        }
        ProviderIcon { anchors.centerIn: parent; width: 20; height: 20; source: r.icon(it.modelData.id); sourceSize.width: 40; sourceSize.height: 40; opacity: it.modelData.error ? 0.4 : 1 }
        MouseArea { anchors.fill: parent; onClicked: r.toggle(it.modelData.id) }
      }
    }
  }
  Row {
    x: 10; y: parent.height - 44; spacing: 4; visible: false  // rail foot is too short with 7 providers; buttons live in the inbox header instead
  }

  // focus
  Item {
    x: 90; y: 12; width: 480; height: parent.height - 50
    visible: !!v.picked
    Row { spacing: 10
      ProviderIcon { width: 28; height: 28; source: v.picked ? r.icon(v.picked.id) : ""; sourceSize.width: 56; sourceSize.height: 56 }
      Text { text: v.picked ? v.picked.name : ""; font.family: r.t.font; font.pixelSize: 20; font.bold: true; color: r.t.fgBright }
      Text { anchors.baseline: parent.children[1].baseline; text: v.picked ? (v.picked.error || v.picked.plan || "") : ""; font.pixelSize: 13; color: v.picked && v.picked.error ? r.t.danger : r.t.muted } }
    Text { anchors.right: parent.right; y: -6; text: v.picked && !v.picked.error ? r.pct(v.picked.remaining) : ""; font.family: r.t.font; font.pixelSize: 54; font.bold: true; color: v.picked ? r.level(v.picked.remaining) : r.t.fg }
    Column {
      y: 72; width: parent.width; spacing: 12
      Repeater {
        model: v.picked ? v.picked.windows || [] : []
        delegate: Column {
          required property var modelData
          width: parent.width; spacing: 4
          Row { width: parent.width
            Text { width: parent.width - pp.width; text: modelData.label + (modelData.primary ? "  ★" : "") + "    " + (modelData.resetLabel || ""); font.family: r.t.font; font.pixelSize: 13; color: r.t.fg }
            Text { id: pp; text: r.pct(modelData.remaining); font.family: r.t.font; font.pixelSize: 15; font.bold: true; color: r.t.fgBright } }
          Rectangle { width: parent.width; height: 12; radius: 6; color: r.t.sel
            Rectangle { width: parent.width * (modelData.remaining ?? 0); height: 12; radius: 6; color: r.level(modelData.remaining) } }
        }
      }
    }
  }

  // inbox (dense)
  Rectangle { x: 586; y: 0; width: 374; height: parent.height; color: r.t.bgDark }
  Item {
    x: 596; y: 10; width: 354; height: parent.height - 50
    Row { id: h; width: parent.width; height: 24
      Text { width: parent.width - b.width; text: "  " + r.visibleNotes().length; font.family: r.t.font; font.pixelSize: 13; color: r.t.muted }
      Row { id: b; spacing: 18
        Text { text: r.dnd ? " DND" : " on"; font.family: r.t.font; font.pixelSize: 13; color: r.dnd ? r.t.warn : r.t.fg
          MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: r.toggleDnd() } }
        Text { text: ""; font.family: r.t.font; font.pixelSize: 15; color: r.t.fg
          MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: r.openSettings() } } } }
    ListView {
      y: 30; width: parent.width; height: parent.height - 30; clip: true; spacing: 2
      model: r.visibleNotes()
      delegate: Rectangle {
        required property var modelData
        width: ListView.view.width; height: 30; radius: 6; color: ma.pressed ? r.t.sel : "transparent"
        Row { anchors.verticalCenter: parent.verticalCenter; x: 6; spacing: 8; width: parent.width - 12
          Image { width: 16; height: 16; source: modelData.appIcon || ""; sourceSize.width: 32; sourceSize.height: 32 }
          Text { width: parent.width - 16 - 40 - 16; elide: Text.ElideRight; textFormat: Text.PlainText
            text: modelData.app + " · " + (modelData.summary || modelData.body); font.pixelSize: 12; color: r.t.fg }
          Text { width: 40; horizontalAlignment: Text.AlignRight; text: r.ago(modelData.timestamp); font.family: r.t.font; font.pixelSize: 11; color: r.t.muted } }
        MouseArea { id: ma; anchors.fill: parent; onClicked: r.openNote(modelData); onPressAndHold: r.dismiss(modelData) }
      }
    }
  }
}
