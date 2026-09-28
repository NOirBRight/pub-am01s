import QtQuick
import QtQuick.Effects

// Monochrome Provider mark, tinted to the theme foreground.
Item {
  id: root

  property url source
  property color tint: "#D6D5BC"
  readonly property bool ready: img.status === Image.Ready

  Image {
    id: img
    anchors.fill: parent
    source: root.source
    sourceSize: Qt.size(48, 48)
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: parent
    source: img
    colorization: 1
    colorizationColor: root.tint
    brightness: 1
  }
}
