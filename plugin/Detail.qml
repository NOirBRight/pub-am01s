import QtQuick
import qs.Commons

// Covers the Meter Bank only. Scales out of the tapped column, and back on any tap.
Item {
  id: root

  property var detail: null
  property real progress: 0
  property real originX: 0

  signal closeRequested()

  readonly property color warnOrange: "#a2734b"
  property var barWindows: []

  visible: root.progress > 0.01 && !!root.detail
  opacity: root.progress
  transform: Scale {
    origin.x: root.originX
    origin.y: root.height / 2
    xScale: 0.55 + 0.45 * root.progress
    yScale: 0.9 + 0.1 * root.progress
  }

  function levelColor(level) {
    if (level === "danger") return Color.urgent
    if (level === "warn") return root.warnOrange
    if (level === "ok") return Color.accent
    return Color.muted
  }

  function hasQuota(detail) {
    if (!detail || !detail.windows || !detail.windows.length) return false
    var first = detail.windows[0]
    return !!first && typeof first.remaining === "number"
  }

  // Recreate the bars once the open is underway so they refill instead of appearing full.
  function syncBars() {
    var windows = root.progress > 0.5 && root.hasQuota(root.detail) ? root.detail.windows : null
    if (!windows) {
      if (root.barWindows.length !== 0) root.barWindows = []
      return
    }
    if (root.barWindows !== windows) root.barWindows = windows
  }

  onProgressChanged: syncBars()
  onDetailChanged: syncBars()
  Component.onCompleted: syncBars()

  Rectangle {
    anchors.fill: parent
    color: Qt.lighter(Color.background, 1.12)
  }

  Item {
    id: titleRow
    x: 16
    y: 12
    width: Math.max(0, parent.width - 16 - 64)
    height: 40

    ProviderIcon {
      id: titleIcon
      anchors.verticalCenter: parent.verticalCenter
      width: 28
      height: 28
      source: root.detail ? Qt.resolvedUrl("icons/" + String(root.detail.id || "") + ".svg") : ""
      tint: Color.foreground
    }

    Text {
      id: nameText
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: titleIcon.right
      anchors.leftMargin: 10
      width: Math.min(implicitWidth, Math.max(0, titleRow.width - 38 - (planPill.visible ? planPill.width + 10 : 0)))
      text: root.detail ? root.detail.name : ""
      elide: Text.ElideRight
      font.family: Style.font.resolvedFamily
      font.pixelSize: 24
      font.bold: true
      color: Color.foreground
    }

    Rectangle {
      id: planPill
      visible: root.detail && String(root.detail.plan || "").length > 0
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: nameText.right
      anchors.leftMargin: 10
      height: 24
      radius: 12
      width: planLabel.implicitWidth + 18
      color: Qt.lighter(Color.background, 1.75)

      Text {
        id: planLabel
        anchors.centerIn: parent
        text: root.detail && root.detail.plan ? root.detail.plan : ""
        font.family: Style.font.resolvedFamily
        font.pixelSize: 14
        font.bold: true
        color: Color.foreground
      }
    }
  }

  Text {
    visible: root.detail && root.detail.failed === true && root.barWindows.length > 0
    x: 16
    y: 52
    width: parent.width - 32
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: root.detail ? String(root.detail.reason || "") : ""
    color: Color.urgent
    font.family: Style.font.resolvedFamily
    font.pixelSize: 12
  }

  Text {
    visible: root.detail && root.detail.failed === true && root.barWindows.length === 0
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.leftMargin: 20
    anchors.rightMargin: 20
    anchors.topMargin: 72
    anchors.bottomMargin: 16
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    text: root.detail ? String(root.detail.reason || "") : ""
    color: Color.urgent
    font.family: Style.font.resolvedFamily
    font.pixelSize: 20
    lineHeight: 1.3
  }

  Item {
    id: stage
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.topMargin: root.detail && root.detail.failed === true ? 78 : 64
    anchors.bottomMargin: 12
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    visible: root.barWindows.length > 0

    readonly property int count: root.barWindows ? root.barWindows.length : 0
    readonly property real slotW: count > 0 ? Math.min(170, Math.max(0, width) / count) : 0

    Row {
      id: big
      height: parent.height
      width: stage.slotW * stage.count
      anchors.horizontalCenter: parent.horizontalCenter

      Repeater {
        model: root.barWindows
        delegate: Item {
          id: slot
          required property var modelData
          required property int index

          width: stage.slotW
          height: big.height

          Item {
            id: figure
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44

            CountText {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              value: slot.modelData.remaining
              delayMs: slot.index * 80
              size: slot.modelData.primary ? 34 : 28
              digitColor: slot.modelData.primary ? Color.foreground : Color.muted
            }
          }

          Column {
            id: caption
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 3

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
              text: slot.modelData.label
              font.family: Style.font.resolvedFamily
              font.pixelSize: slot.modelData.primary ? 18 : 16
              font.bold: slot.modelData.primary
              color: slot.modelData.primary ? Color.foreground : Color.muted
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
              text: slot.modelData.resetLabel
              font.family: Style.font.resolvedFamily
              font.pixelSize: 15
              color: slot.modelData.primary ? Color.foreground : Color.muted
            }
          }

          SegBar {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: figure.bottom
            anchors.topMargin: 8
            anchors.bottom: caption.top
            anchors.bottomMargin: 8
            width: slot.modelData.primary ? 40 : 34
            value: slot.modelData.remaining === null || slot.modelData.remaining === undefined ? 0 : slot.modelData.remaining
            delayMs: slot.index * 80
            litColor: root.levelColor(slot.modelData.level)
            pulse: slot.modelData.level === "danger"
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.closeRequested()
  }

  Rectangle {
    id: closeButton
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.top: parent.top
    anchors.topMargin: 12
    width: 38
    height: 38
    radius: 19
    color: closeHit.pressed ? Qt.lighter(Color.background, 1.95) : Qt.lighter(Color.background, 1.55)
    scale: closeHit.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: 100 } }

    Text {
      anchors.centerIn: parent
      text: "×"
      font.family: Style.font.resolvedFamily
      font.pixelSize: 20
      color: Color.foreground
    }

    MouseArea {
      id: closeHit
      anchors.fill: parent
      anchors.margins: -6
      onClicked: root.closeRequested()
    }
  }

  component CountText: Row {
    id: pct
    property var value: null
    property int delayMs: 0
    property int size: 28
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

  component SegBar: Item {
    id: bar
    property real value: 0
    property color litColor: Color.accent
    property color trackColor: Color.muted
    property int seg: 7
    property int gap: 3
    property int delayMs: 0
    property bool pulse: false
    property real shown: 0
    property bool ready: false

    readonly property int count: Math.max(1, Math.floor((height + gap) / (seg + gap)))
    readonly property int lit: Math.round(count * Math.max(0, Math.min(1, shown)))

    clip: true
    Behavior on shown { enabled: bar.ready; NumberAnimation { duration: 750; easing.type: Easing.OutCubic } }
    Timer {
      interval: Math.max(1, bar.delayMs)
      running: true
      onTriggered: {
        bar.ready = true
        bar.shown = Qt.binding(function() { return bar.value })
      }
    }
    onPulseChanged: if (!bar.pulse) bar.opacity = 1

    Item {
      anchors.fill: parent
      SequentialAnimation on opacity {
        running: bar.pulse
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
      }

      Repeater {
        model: bar.count
        delegate: Rectangle {
          required property int index
          readonly property bool on: index < bar.lit
          width: bar.width
          height: bar.seg
          radius: 2
          y: bar.height - (index + 1) * (bar.seg + bar.gap) + bar.gap
          color: on ? (index === bar.lit - 1 ? Qt.lighter(bar.litColor, 1.25) : bar.litColor) : bar.trackColor
          opacity: on ? 1 : 0.45
          Behavior on color { ColorAnimation { duration: 120 } }
        }
      }
    }
  }
}
