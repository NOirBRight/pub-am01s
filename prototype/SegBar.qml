// PROTOTYPE shared bit: segmented LED meter that fills from the bottom,
// animating from 0 after `delay` ms, then easing to any new value.
import QtQuick

Item {
  id: bar
  property real value: 0
  property color color: "#509475"
  property color track: "#32473B"
  property int seg: 6
  property int gap: 3
  property int delay: 0
  property bool pulse: false
  property real shown: 0
  property bool ready: false
  readonly property int count: Math.max(1, Math.floor((height + gap) / (seg + gap)))
  readonly property int lit: Math.round(count * Math.max(0, Math.min(1, shown)))

  Behavior on shown { enabled: bar.ready; NumberAnimation { duration: 750; easing.type: Easing.OutCubic } }
  Timer { interval: Math.max(1, bar.delay); running: true; onTriggered: { bar.ready = true; bar.shown = Qt.binding(() => bar.value) } }

  Item {
    anchors.fill: parent
    SequentialAnimation on opacity {
      running: bar.pulse; loops: Animation.Infinite
      NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
      NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
    }
    Repeater {
      model: bar.count
      Rectangle {
        required property int index
        readonly property bool on: index < bar.lit
        width: bar.width; height: bar.seg; radius: 2
        y: bar.height - (index + 1) * (bar.seg + bar.gap) + bar.gap
        color: on ? (index === bar.lit - 1 ? Qt.lighter(bar.color, 1.25) : bar.color) : bar.track
        opacity: on ? 1 : 0.5
        Behavior on color { ColorAnimation { duration: 120 } }
      }
    }
  }
}
