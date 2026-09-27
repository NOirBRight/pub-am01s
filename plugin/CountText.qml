import QtQuick
import qs.Commons

Row {
  id: pct

  property var value: null
  property int delayMs: 0
  property int size: 18
  property color digitColor: Color.foreground
  property real shown: 0
  property bool ready: false

  spacing: 1
  Behavior on shown { enabled: pct.ready; NumberAnimation { duration: 750; easing.type: Easing.OutCubic } }
  Timer {
    interval: Math.max(1, pct.delayMs)
    running: true
    onTriggered: {
      pct.ready = true
      pct.shown = Qt.binding(function() { return pct.value === null || pct.value === undefined ? 0 : pct.value })
    }
  }

  Text {
    id: digits
    text: pct.value === null || pct.value === undefined ? "—" : String(Math.round(pct.shown * 100))
    font.family: Style.font.resolvedFamily
    font.pixelSize: pct.size
    font.bold: true
    color: pct.digitColor
  }
  Text {
    visible: pct.value !== null && pct.value !== undefined
    anchors.baseline: digits.baseline
    text: "%"
    font.family: Style.font.resolvedFamily
    font.pixelSize: Math.round(pct.size * 0.55)
    font.bold: true
    color: pct.digitColor
    opacity: 0.7
  }
}
