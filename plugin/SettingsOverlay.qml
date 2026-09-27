import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Focused main screen. Creatable while the AM01S panel loader is inactive.
Item {
  id: root

  property var targetScreen: null
  property var providers: []
  property bool remainingMode: true
  property string status: ""
  property string message: ""

  signal closeRequested()
  signal enabledToggled(string id, bool enabled)
  signal remainingModeToggled(bool remainingMode)

  readonly property bool messageUrgent: root.status === "error" || (root.status === "ok" && root.message.length > 0)
  readonly property bool showEditors: root.status === "ok"

  function requestClose() {
    root.closeRequested()
  }

  PanelWindow {
    id: panel

    visible: root.targetScreen !== null
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    WlrLayershell.namespace: "pub-am01s-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) keyScope.forceActiveFocus()

    FocusScope {
      id: keyScope
      anchors.fill: parent
      focus: true

      Keys.onEscapePressed: function(event) {
        root.requestClose()
        event.accepted = true
      }

      Rectangle {
        anchors.fill: parent
        color: Color.menu.scrim

        MouseArea {
          anchors.fill: parent
          onClicked: root.requestClose()
        }
      }

      Rectangle {
        id: card
        width: Math.min(480, Math.max(280, parent.width - 64))
        height: Math.min(640, Math.max(240, parent.height - 80))
        anchors.centerIn: parent
        radius: Math.max(12, Style.cornerRadius)
        color: Color.menu.background
        border.width: 1
        border.color: Color.menu.border

        MouseArea {
          anchors.fill: parent
          onClicked: function(mouse) { mouse.accepted = true }
        }

        Column {
          id: body
          anchors.fill: parent
          anchors.margins: 18
          spacing: 14

          Row {
            width: parent.width
            height: 32
            spacing: 12

            Text {
              width: parent.width - closeButton.width - parent.spacing
              height: parent.height
              text: "设置"
              color: Color.menu.text
              font.family: Style.font.resolvedFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            Rectangle {
              id: closeButton
              width: 64
              height: 32
              radius: 16
              color: Color.menu.selectedBackground

              Text {
                anchors.centerIn: parent
                text: "关闭"
                color: Color.menu.text
                font.family: Style.font.resolvedFamily
                font.pixelSize: Style.font.body
                textFormat: Text.PlainText
              }

              MouseArea {
                anchors.fill: parent
                onClicked: root.requestClose()
              }
            }
          }

          Text {
            width: parent.width
            visible: root.message.length > 0
            text: root.message
            color: root.messageUrgent ? Color.urgent : Color.menu.text
            font.family: Style.font.resolvedFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
          }

          Row {
            width: parent.width
            height: 36
            visible: root.showEditors
            spacing: 12

            Text {
              width: parent.width - modeSwitch.width - parent.spacing
              height: parent.height
              text: "百分比读法"
              color: Color.menu.text
              font.family: Style.font.resolvedFamily
              font.pixelSize: Style.font.subtitle
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
              textFormat: Text.PlainText
            }

            Row {
              id: modeSwitch
              height: 32
              spacing: 0

              Rectangle {
                width: 72
                height: 32
                radius: 8
                color: root.remainingMode ? Color.accent : Color.menu.selectedBackground

                Text {
                  anchors.centerIn: parent
                  text: "剩余"
                  color: root.remainingMode ? Color.menu.selectedText : Color.menu.text
                  font.family: Style.font.resolvedFamily
                  font.pixelSize: Style.font.body
                  textFormat: Text.PlainText
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: if (!root.remainingMode) root.remainingModeToggled(true)
                }
              }

              Rectangle {
                width: 72
                height: 32
                radius: 8
                color: root.remainingMode ? Color.menu.selectedBackground : Color.accent

                Text {
                  anchors.centerIn: parent
                  text: "已用"
                  color: root.remainingMode ? Color.menu.text : Color.menu.selectedText
                  font.family: Style.font.resolvedFamily
                  font.pixelSize: Style.font.body
                  textFormat: Text.PlainText
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: if (root.remainingMode) root.remainingModeToggled(false)
                }
              }
            }
          }

          Flickable {
            width: parent.width
            height: Math.max(0, parent.height - y)
            visible: root.showEditors
            clip: true
            contentWidth: width
            contentHeight: providerColumn.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: providerColumn
              width: parent.width
              spacing: 8

              Repeater {
                model: root.providers

                delegate: Rectangle {
                  id: row
                  required property var modelData
                  required property int index

                  width: providerColumn.width
                  height: modelData.loginLabel ? 64 : 52
                  radius: 10
                  color: Color.menu.selectedBackground

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Column {
                      width: parent.width - track.width - parent.spacing
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: 2

                      Text {
                        width: parent.width
                        text: modelData.name || modelData.id
                        color: Color.menu.text
                        font.family: Style.font.resolvedFamily
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                      }

                      Text {
                        width: parent.width
                        visible: String(modelData.loginLabel || "").length > 0
                        text: modelData.loginLabel || ""
                        color: Color.urgent
                        font.family: Style.font.resolvedFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                      }
                    }

                    Rectangle {
                      id: track
                      width: 44
                      height: 26
                      radius: 13
                      anchors.verticalCenter: parent.verticalCenter
                      color: modelData.enabled === true ? Color.accent : Color.muted

                      Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        y: 4
                        x: modelData.enabled === true ? parent.width - width - 4 : 4
                        color: Color.background
                      }
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: root.enabledToggled(String(modelData.id || ""), modelData.enabled !== true)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
