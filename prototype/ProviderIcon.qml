// PROTOTYPE shared bit: monochrome Provider SVG tinted to the theme foreground.
import QtQuick
import QtQuick.Effects

Item {
  property url source
  property size sourceSize: Qt.size(48, 48)
  property color tint: "#D6D5BC"
  Image { id: img; anchors.fill: parent; source: parent.source; sourceSize: parent.sourceSize; visible: false; layer.enabled: true }
  MultiEffect { anchors.fill: parent; source: img; colorization: 1; colorizationColor: parent.tint; brightness: 1 }
}
