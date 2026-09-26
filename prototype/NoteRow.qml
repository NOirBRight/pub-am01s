// PROTOTYPE shared bit: one notification. Tap = open (execArgv), swipe left = dismiss.
import QtQuick

Item {
  id: row
  required property var r
  required property var n
  property bool big: false
  height: big ? 110 : 82
  clip: true

  Rectangle { anchors.fill: parent; color: r.t.danger; radius: 8
    Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
      text: ""; font.family: r.t.font; font.pixelSize: 18; color: r.t.fgBright } }

  Rectangle {
    id: card
    width: parent.width; height: parent.height; radius: 8
    color: n.urgency === 2 ? "#3a2020" : r.t.bgLight
    Behavior on x { NumberAnimation { duration: 140 } }
    Rectangle {
      id: ico; x: 10; y: 10; width: 36; height: width; radius: 6; color: r.t.sel
      Text { anchors.centerIn: parent; visible: !row.n.appIcon; text: (row.n.app || "?")[0].toUpperCase(); font.bold: true; font.pixelSize: parent.width * 0.5; color: r.t.fgDim }
      Image { anchors.fill: parent; source: row.n.appIcon || ""; sourceSize.width: 64; sourceSize.height: 64; fillMode: Image.PreserveAspectCrop }
    }
    Column {
      anchors { left: ico.right; leftMargin: 10; right: parent.right; rightMargin: 10; top: parent.top; topMargin: 8 }
      spacing: 2
      Row {
        width: parent.width
        Text { width: parent.width - when.width; text: row.n.app + (row.n.summary ? " · " + row.n.summary : ""); elide: Text.ElideRight
          font.family: r.t.font; font.pixelSize: 16; font.bold: true; color: r.t.fgBright }
        Text { id: when; text: r.ago(row.n.timestamp); font.family: r.t.font; font.pixelSize: 13; color: r.t.muted }
      }
      Text { width: parent.width; text: row.n.body || ""; wrapMode: Text.Wrap; maximumLineCount: row.big ? 4 : 2; elide: Text.ElideRight
        font.pixelSize: 15; color: r.t.fg; textFormat: Text.PlainText }
    }
    MouseArea {
      anchors.fill: parent
      drag.target: card; drag.axis: Drag.XAxis; drag.maximumX: 0; drag.minimumX: -row.width
      onReleased: {
        if (card.x < -row.width * 0.3) r.dismiss(row.n)
        else { if (Math.abs(card.x) < 6) r.openNote(row.n); card.x = 0 }
      }
    }
  }
}
