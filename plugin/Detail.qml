import QtQuick
import qs.Commons

// Covers the Meter Bank only. Scales out of the tapped column, and back on any tap.
Item {
  id: root

  property var detail: null
  property real progress: 0
  property real originX: 0

  signal closeRequested()

  property color warnOrange: Color.urgent
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
    var windows = detail.windows
    var count = windows.length
    for (var i = 0; i < count; i++) {
      if (windows[i] && typeof windows[i].remaining === "number") return true
    }
    return false
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
            height: 28

            CountText {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              value: slot.modelData.remaining
              delayMs: slot.index * 80
              size: 22
              digitColor: slot.modelData.primary ? Color.foreground : Color.muted
            }
          }

          Column {
            id: caption
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 2

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              wrapMode: Text.NoWrap
              maximumLineCount: 1
              textFormat: Text.PlainText
              text: slot.modelData.label
              font.family: Style.font.resolvedFamily
              font.pixelSize: 13
              font.bold: false
              color: slot.modelData.primary ? Color.foreground : Color.muted
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              wrapMode: Text.NoWrap
              maximumLineCount: 1
              textFormat: Text.PlainText
              text: slot.modelData.resetLabel
              font.family: Style.font.resolvedFamily
              font.pixelSize: 12
              color: slot.modelData.primary ? Color.foreground : Color.muted
            }
          }

          SegBar {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: figure.bottom
            anchors.topMargin: 8
            anchors.bottom: caption.top
            anchors.bottomMargin: 8
            width: 34
            seg: 7
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

}
