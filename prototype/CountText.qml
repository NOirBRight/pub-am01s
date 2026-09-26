// PROTOTYPE shared bit: percentage that counts up with the bar beside it.
import QtQuick

Row {
  id: c
  property var value: null      // 0..1 or null
  property int delay: 0
  property int size: 22
  property color color: "#F7E8B2"
  property string family: "JetBrainsMono Nerd Font"
  property real shown: 0
  property bool ready: false
  Behavior on shown { enabled: c.ready; NumberAnimation { duration: 750; easing.type: Easing.OutCubic } }
  Timer { interval: Math.max(1, c.delay); running: true; onTriggered: { c.ready = true; c.shown = Qt.binding(() => c.value ?? 0) } }
  spacing: 1
  Text { text: c.value === null || c.value === undefined ? "—" : Math.round(c.shown * 100); font.family: c.family; font.pixelSize: c.size; font.bold: true; color: c.color }
  Text { visible: c.value !== null && c.value !== undefined; anchors.baseline: parent.children[0].baseline; text: "%"; font.family: c.family; font.pixelSize: Math.round(c.size * 0.55); font.bold: true; color: c.color; opacity: 0.7 }
}
