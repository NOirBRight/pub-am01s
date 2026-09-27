import QtQuick
import qs.Commons
import "meter-model.mjs" as MeterModel

// Segmented vertical level bars for the Meter Bank. Commons has no orange
// role; theme red is Color.urgent.
Item {
  id: root

  property var snapshot: null
  property string snapshotStatus: "no-engine"
  property real canvasWidth: 960

  readonly property color warnOrange: "#a2734b"
  readonly property var layout: MeterModel.layoutMeterBank(root.snapshot === null ? ({ providers: [] }) : root.snapshot, root.canvasWidth)
  readonly property bool showBars: root.snapshotStatus === "ok" && root.layout.providers.length > 0
  readonly property bool wide: root.layout.mode === "wide"

  property bool detailOpen: false
  property string detailShownId: ""
  property real detailOriginX: 0
  property real detailProgress: root.detailOpen ? 1 : 0
  Behavior on detailProgress { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
  readonly property var openDetail: MeterModel.detailFor(root.snapshot === null ? ({ providers: [] }) : root.snapshot, root.detailShownId)

  onShowBarsChanged: if (!root.showBars) root.detailOpen = false
  onDetailOpenChanged: if (root.detailOpen && !root.openDetail) root.detailOpen = false
  onOpenDetailChanged: if (root.detailOpen && !root.openDetail) root.detailOpen = false

  function levelColor(level) {
    if (level === "danger") return Color.urgent
    if (level === "warn") return root.warnOrange
    if (level === "ok") return Color.accent
    return Color.muted
  }

  readonly property string statusTitle: {
    if (root.snapshotStatus === "needs-update") return "需要更新"
    if (root.snapshotStatus === "unreadable") return "无法读取"
    if (root.snapshotStatus === "pending") return "读取中"
    if (root.snapshotStatus === "no-engine") return "未配置 Engine"
    return ""
  }
  readonly property string statusDetail: {
    if (root.snapshotStatus === "needs-update") return "这个面板只认识 Snapshot schemaVersion 1。"
    if (root.snapshotStatus === "unreadable") return "Engine 没有返回可读的 Snapshot。"
    if (root.snapshotStatus === "no-engine") return "在配置里写 enginePath，或设置 PUB_ENGINE。"
    return ""
  }

  clip: true

  Column {
    visible: !root.showBars && root.statusTitle.length > 0
    anchors.verticalCenter: parent.verticalCenter
    x: 4
    width: parent.width - 8
    spacing: 6

    Text {
      width: parent.width
      text: root.statusTitle
      color: Color.foreground
      font.family: Style.font.resolvedFamily
      font.pixelSize: 18
      font.bold: true
      wrapMode: Text.Wrap
    }
    Text {
      width: parent.width
      visible: root.statusDetail.length > 0
      text: root.statusDetail
      color: Color.muted
      font.family: Style.font.resolvedFamily
      font.pixelSize: 13
      wrapMode: Text.Wrap
    }
  }

  Row {
    id: cols
    visible: root.showBars
    opacity: 1 - root.detailProgress
    scale: 1 - 0.05 * root.detailProgress
    width: parent.width
    height: parent.height

    Repeater {
      model: root.layout.providers
      delegate: Item {
        id: col
        required property var modelData
        required property int index

        readonly property bool failed: col.modelData.error !== null && col.modelData.error !== undefined && String(col.modelData.error).length > 0

        width: col.modelData.width
        height: cols.height

        Rectangle {
          visible: col.index > 0
          width: 1
          y: parent.height * 0.1
          height: parent.height * 0.8
          color: Color.muted
          opacity: 0.7
        }

        Item {
          id: body
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          opacity: 0
          scale: hit.pressed ? 0.96 : 1
          transform: Translate { id: lift; y: 14 }
          Behavior on scale { NumberAnimation { duration: 110 } }

          SequentialAnimation {
            running: true
            PauseAnimation { duration: col.index * 70 }
            ParallelAnimation {
              NumberAnimation { target: body; property: "opacity"; to: 1; duration: 320 }
              NumberAnimation { target: lift; property: "y"; to: 0; duration: 420; easing.type: Easing.OutCubic }
            }
          }

          Column {
            visible: col.failed
            anchors.centerIn: parent
            width: parent.width
            spacing: 6

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: "!"
              color: Color.urgent
              font.family: Style.font.resolvedFamily
              font.pixelSize: 22
              font.bold: true
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: col.modelData.displayName
              color: Color.urgent
              font.family: Style.font.resolvedFamily
              font.pixelSize: 12
              font.bold: true
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              text: col.modelData.error
              color: Color.urgent
              font.family: Style.font.resolvedFamily
              font.pixelSize: 12
            }
          }

          Item {
            anchors.fill: parent
            visible: root.wide && !col.failed

            Row {
              id: head
              y: 2
              width: parent.width
              spacing: 7
              clip: true

              Text {
                id: nameText
                text: col.modelData.displayName
                width: Math.max(0, head.width - (planText.visible ? planText.implicitWidth + head.spacing : 0))
                elide: Text.ElideRight
                font.family: Style.font.resolvedFamily
                font.pixelSize: 14
                font.bold: true
                color: Color.foreground
              }
              Text {
                id: planText
                visible: col.modelData.width >= 170 && String(col.modelData.plan || "").length > 0
                text: col.modelData.plan || ""
                font.family: Style.font.resolvedFamily
                font.pixelSize: 12
                color: Color.muted
              }
            }

            Row {
              id: subs
              y: 34
              width: parent.width
              height: parent.height - 34
              readonly property int count: Math.max(1, col.modelData.windows.length)

              Repeater {
                model: col.modelData.windows
                delegate: Item {
                  id: slot
                  required property var modelData
                  required property int index
                  width: subs.width / subs.count
                  height: subs.height

                  CountText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    value: slot.modelData.remaining
                    delayMs: col.index * 70 + 120 + slot.index * 60
                    size: slot.modelData.primary ? 24 : 18
                    digitColor: slot.modelData.primary ? Color.foreground : Color.muted
                  }
                  SegBar {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 40
                    width: 20
                    height: parent.height - 40 - 40
                    value: slot.modelData.remaining === null || slot.modelData.remaining === undefined ? 0 : slot.modelData.remaining
                    delayMs: col.index * 70 + 120 + slot.index * 60
                    litColor: root.levelColor(slot.modelData.level)
                    pulse: slot.modelData.level === "danger"
                  }
                  Column {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 1

                    Text {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                      text: slot.modelData.displayLabel
                      font.family: Style.font.resolvedFamily
                      font.pixelSize: 12
                      font.bold: slot.modelData.primary
                      color: slot.modelData.primary ? Color.foreground : Color.muted
                    }
                    Text {
                      width: parent.width
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                      text: slot.modelData.resetAbbrev
                      font.family: Style.font.resolvedFamily
                      font.pixelSize: 11
                      color: Color.muted
                    }
                  }
                }
              }
            }
          }

          Item {
            anchors.fill: parent
            visible: !root.wide && !col.failed

            CountText {
              anchors.horizontalCenter: parent.horizontalCenter
              y: 2
              value: col.modelData.windows.length > 0 ? col.modelData.windows[0].remaining : null
              delayMs: col.index * 70 + 120
              size: 20
              digitColor: Color.foreground
            }
            SegBar {
              anchors.horizontalCenter: parent.horizontalCenter
              y: 36
              width: 20
              height: parent.height - 36 - 28
              value: col.modelData.windows.length > 0 && col.modelData.windows[0].remaining !== null && col.modelData.windows[0].remaining !== undefined ? col.modelData.windows[0].remaining : 0
              delayMs: col.index * 70 + 120
              litColor: root.levelColor(col.modelData.windows.length > 0 ? col.modelData.windows[0].level : "none")
              pulse: col.modelData.windows.length > 0 && col.modelData.windows[0].level === "danger"
            }
            Text {
              anchors.bottom: parent.bottom
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: col.modelData.displayName
              font.family: Style.font.resolvedFamily
              font.pixelSize: 11
              color: Color.muted
            }
          }
        }

        MouseArea {
          id: hit
          anchors.fill: parent
          onClicked: {
            root.detailOriginX = col.x + col.width / 2
            root.detailShownId = String(col.modelData.id || "")
            root.detailOpen = true
          }
        }
      }
    }
  }

  Detail {
    anchors.fill: parent
    detail: root.openDetail
    progress: root.detailProgress
    originX: root.detailOriginX
    onCloseRequested: root.detailOpen = false
  }

  component CountText: Row {
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

  component SegBar: Item {
    id: bar
    property real value: 0
    property color litColor: Color.accent
    property color trackColor: Color.muted
    property int seg: 6
    property int gap: 3
    property int delayMs: 0
    property bool pulse: false
    property real shown: 0
    property bool ready: false

    readonly property int count: Math.max(1, Math.floor((height + gap) / (seg + gap)))
    readonly property int lit: Math.round(count * Math.max(0, Math.min(1, shown)))

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
