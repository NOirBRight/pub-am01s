import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons

// Loaded only after a screen matches, so offscreen sessions never construct a PanelWindow.
Item {
  id: root

  property var targetScreen: null
  property real uiScale: 1.25

  readonly property real safeScale: root.uiScale >= 1 && root.uiScale <= 1.4 ? root.uiScale : 1.25

  PanelWindow {
    id: panel

    // Stay unmapped until the matched screen is assigned, including the
    // moment before Loader applies the initial properties.
    visible: root.targetScreen !== null
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: Color.background
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false

    WlrLayershell.namespace: "pub-am01s"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Design canvas is 960×400 divided by UI Scale, then stretched onto the output.
    Item {
      id: canvas
      width: 960 / root.safeScale
      height: 400 / root.safeScale
      transformOrigin: Item.TopLeft
      transform: Scale {
        origin.x: 0
        origin.y: 0
        xScale: canvas.width > 0 ? panel.width / canvas.width : 1
        yScale: canvas.height > 0 ? panel.height / canvas.height : 1
      }
    }
  }
}
