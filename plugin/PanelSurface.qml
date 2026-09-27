import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "theme-colors.mjs" as ThemeColors

// Loaded only after a screen matches, so offscreen sessions never construct a PanelWindow.
Item {
  id: root

  property var targetScreen: null
  property real uiScale: 1.25
  property var shell: null
  property var snapshot: null
  property string snapshotStatus: "no-engine"

  signal settingsRequested()

  property var themeColors: ThemeColors.parseTheme("")
  readonly property real safeScale: root.uiScale >= 1 && root.uiScale <= 1.4 ? root.uiScale : 1.25

  FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeColors = ThemeColors.parseTheme(text())
    onFileChanged: reload()
  }

  PanelWindow {
    id: panel

    // Stay unmapped until the matched screen is assigned, including the
    // moment before Loader applies the initial properties.
    visible: root.targetScreen !== null
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false

    WlrLayershell.namespace: "pub-am01s"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.lighter(Color.background, 1.28) }
        GradientStop { position: 1; color: Qt.darker(Color.background, 1.45) }
      }
    }

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

      MeterBank {
        id: meterBank
        x: 10
        y: 12
        height: parent.height - 24
        canvasWidth: parent.width
        snapshot: root.snapshot
        snapshotStatus: root.snapshotStatus
        themeOrange: root.themeColors.orange
        width: {
          var resting = 0
          if (meterBank.snapshotStatus === "ok") resting = meterBank.layout.meterWidth
          else if (meterBank.snapshotStatus === "needs-update" || meterBank.snapshotStatus === "unreadable") resting = 240
          if (meterBank.detailOpen && meterBank.layout.maxWidth > resting) return meterBank.layout.maxWidth
          return resting
        }
        Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
      }

      Rectangle {
        visible: meterBank.width > 1
        width: 1
        x: meterBank.x + meterBank.width + 5
        y: 12
        height: parent.height - 24
        color: Color.muted
        opacity: 0.55
      }

      InboxColumn {
        id: inbox
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: meterBank.right
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        anchors.rightMargin: 10
        shell: root.shell
        themeOrange: root.themeColors.orange
        themeBgLight: root.themeColors.bgLight
        themeSel: root.themeColors.sel
        themeFgBright: root.themeColors.fgBright
        themeFgDim: root.themeColors.fgDim
        themeBgDark: root.themeColors.bgDark
        onSettingsRequested: root.settingsRequested()
      }
    }
  }
}
