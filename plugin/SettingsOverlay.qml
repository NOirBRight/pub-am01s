import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "settings-model.mjs" as SettingsModel

// Focused main screen. Creatable while the AM01S panel loader is inactive.
Item {
  id: root

  property var targetScreen: null
  property var providers: []
  property bool remainingMode: true
  property string status: ""
  property string message: ""
  property string enginePath: ""
  // ["node", pinned.mjs] or [configured engine]. Credentials must use this, not the path alone.
  property var engineLead: []

  signal closeRequested()
  signal enabledToggled(string id, bool enabled)
  signal orderMoved(string id, int direction)
  signal remainingModeToggled(bool remainingMode)
  signal loginChanged()

  property string activeId: ""
  property string activeMode: ""
  property string notice: ""
  property bool noticeUrgent: false
  property string authUrl: ""
  property bool codeSent: false
  property bool codeRejected: false
  property bool codePipeClosed: false
  property bool cliActive: false
  property bool cliRestart: false
  property bool cliSilent: false
  property bool cliSawExit: false
  property int cliGeneration: 0
  property var pendingCli: []
  property bool credActive: false
  property bool credSawExit: false
  property int credGeneration: 0
  property string credKind: ""

  readonly property var activeProvider: {
    var rows = root.providers
    if (!rows || root.activeId.length === 0) return null
    var count = rows.length || 0
    for (var i = 0; i < count; i++) {
      var row = rows[i]
      if (row && String(row.id || "") === root.activeId) return row
    }
    return null
  }

  function trimText(value) {
    return String(value || "").replace(/^\s+|\s+$/g, "")
  }

  function note(text, urgent) {
    root.notice = String(text || "")
    root.noticeUrgent = urgent === true && root.notice.length > 0
  }

  function engineError(text, fallback) {
    var trimmed = root.trimText(text)
    if (trimmed.length > 240) trimmed = trimmed.slice(0, 240)
    return trimmed.length > 0 ? trimmed : fallback
  }

  function beginCli(row) {
    var argv = SettingsModel.cliLoginCommand(row)
    if (!argv || !argv.length) {
      root.activeId = row && row.id ? String(row.id) : ""
      root.activeMode = "cli"
      root.note("没有官方 CLI 命令", true)
      return
    }
    var command = []
    for (var i = 0; i < argv.length; i++) command.push(String(argv[i]))
    root.activeId = String(row.id || "")
    root.activeMode = "cli"
    root.note("", false)
    codeField.text = ""
    if (cliProc.running || root.cliActive) {
      root.cliRestart = true
      root.cliSilent = false
      root.pendingCli = command
      if (cliProc.running) cliProc.running = false
      return
    }
    root.launchCli(command)
  }

  // Catalog bin + args. The process is waited on here; a zero exit is not a browser check.
  function launchCli(argv) {
    if (!argv || !argv.length) return
    root.cliGeneration += 1
    root.cliActive = true
    root.cliSawExit = false
    root.cliSilent = false
    root.codeSent = false
    root.codeRejected = false
    root.codePipeClosed = false
    root.authUrl = ""
    var command = []
    for (var i = 0; i < argv.length; i++) command.push(String(argv[i]))
    cliProc.stdinEnabled = true
    cliProc.environment = { "NO_COLOR": "1" }
    cliProc.command = command
    cliProc.running = true
  }

  function stopCli() {
    root.cliRestart = false
    root.pendingCli = []
    if (!cliProc.running && !root.cliActive) return
    root.cliSilent = true
    if (cliProc.running) cliProc.running = false
    else {
      root.cliActive = false
      root.cliSilent = false
    }
  }

  function beginPaste(row) {
    if (!row) return
    root.stopCli()
    root.activeId = String(row.id || "")
    root.activeMode = "paste"
    root.codeSent = false
    root.codeRejected = false
    root.authUrl = ""
    secretField.text = ""
    extraField.text = ""
    root.note("", false)
    Qt.callLater(function() { if (secretField.visible) secretField.forceActiveFocus() })
  }

  function beginPage(row) {
    if (row && row.page) root.openPage(row.page.url)
    root.beginPaste(row)
  }

  function openPage(url) {
    var target = root.trimText(url)
    if (target.indexOf("https://") !== 0 && target.indexOf("http://") !== 0) return
    pageProc.command = ["xdg-open", target]
    pageProc.startDetached()
  }

  function submitCode(value) {
    if (root.activeMode !== "cli" || !cliProc.running) {
      root.note("登录命令已经结束", true)
      return
    }
    if (root.codePipeClosed) {
      root.note("请取消后重新开始登录", true)
      return
    }
    var code = root.trimText(value)
    if (!code) return
    cliProc.write(code + "\n")
    // One line, then EOF. A rejected code cannot be written again on this process.
    cliProc.stdinEnabled = false
    root.codePipeClosed = true
    root.codeSent = true
    root.codeRejected = false
    codeField.text = ""
    root.note("", false)
  }

  function onCliLine(line) {
    if (!root.cliActive) return
    var text = String(line || "")
    var url = SettingsModel.loginUrl(text)
    if (url.length > 0 && root.authUrl.length === 0) root.authUrl = url
    var row = root.activeProvider
    if (!row || !row.codeEntry) return
    if (SettingsModel.isInvalidCodeLine(text, row.codeEntry)) {
      root.codeRejected = true
      root.note("授权码无效或已过期", true)
    }
  }

  function finishCli(generation, exitCode) {
    cliFailTimer.stop()
    if (generation !== root.cliGeneration) return
    if (root.cliRestart && root.pendingCli && root.pendingCli.length > 0) {
      var next = root.pendingCli
      root.cliRestart = false
      root.pendingCli = []
      root.cliSilent = false
      root.launchCli(next)
      return
    }
    var silent = root.cliSilent
    root.cliSilent = false
    root.cliActive = false
    if (silent) return
    if (Number(exitCode) === 0 && root.codeRejected !== true) {
      root.activeMode = ""
      root.note("登录命令已结束，正在刷新", false)
      root.loginChanged()
      return
    }
    if (root.notice.length === 0) root.note("登录没有完成", true)
  }

  function savePaste() {
    var row = root.activeProvider
    if (!row || root.credActive) return
    var secret = root.trimText(secretField.text)
    if (!secret) {
      root.note("先粘贴凭据。", true)
      return
    }
    var extras = {}
    if (row.extra && row.extra.key) extras[String(row.extra.key)] = extraField.text
    var argv = SettingsModel.credentialsSetCommand(row, extras)
    if (!argv || !argv.length) {
      var hint = row.extra && row.extra.hint ? String(row.extra.hint) : "附加项"
      root.note("还需要填写 " + hint + "。", true)
      return
    }
    secretField.text = ""
    extraField.text = ""
    root.runCredentials(argv, secret, "set")
  }

  function clearCredential(row) {
    if (!row || row.clearOffered !== true || root.credActive) return
    var argv = SettingsModel.credentialsClearCommand(String(row.id || ""))
    if (!argv) return
    root.activeId = String(row.id || "")
    root.runCredentials(argv, "", "clear")
  }

  // Secret is pendingSecret until the process starts, then stdin. Never argv.
  function runCredentials(argv, secret, kind) {
    var lead = root.engineLead
    var leadCount = lead && lead.length ? lead.length : 0
    if (leadCount === 0) {
      root.note("Engine is not configured", true)
      return
    }
    if (root.credActive || credProc.running) return
    var command = []
    for (var j = 0; j < leadCount; j++) command.push(String(lead[j]))
    for (var i = 0; i < argv.length; i++) command.push(String(argv[i]))
    var body = String(secret || "")
    root.credGeneration += 1
    root.credKind = String(kind || "")
    root.credSawExit = false
    root.credActive = true
    credProc.credStderr = ""
    credProc.pendingSecret = body.length > 0 ? body + "\n" : ""
    credProc.stdinEnabled = body.length > 0
    credProc.command = command
    credProc.running = true
  }

  function finishCred(generation, exitCode, err) {
    if (generation !== root.credGeneration || !root.credActive) return
    root.credActive = false
    credProc.pendingSecret = ""
    if (credProc.stdinEnabled) credProc.stdinEnabled = false
    if (Number(exitCode) !== 0) {
      root.note(root.engineError(err, "凭据没有写入"), true)
      return
    }
    root.activeMode = ""
    root.note(root.credKind === "clear" ? "已移除，正在刷新" : "已保存，正在刷新", false)
    root.loginChanged()
  }

  function cancelActive() {
    root.stopCli()
    root.activeMode = ""
    root.activeId = ""
    root.authUrl = ""
    root.codeSent = false
    root.codeRejected = false
    secretField.text = ""
    extraField.text = ""
    codeField.text = ""
    root.note("", false)
  }

  readonly property int providerCount: root.providers && root.providers.length ? root.providers.length : 0
  readonly property int enabledCount: {
    var n = 0
    for (var i = 0; i < root.providerCount; i++) if (root.providers[i] && root.providers[i].enabled === true) n++
    return n
  }
  readonly property bool messageUrgent: root.status === "error" || (root.status === "ok" && root.message.length > 0)
  readonly property bool showEditors: root.status === "ok"
  readonly property bool formOpen: root.activeMode === "cli" || root.activeMode === "paste"
  // One Provider row is open at a time; a login form lives inside the open row.
  property string expandedId: ""

  // Menu surfaces in the theme are often translucent. This card sits over
  // whatever window is focused, so the fill and the ink have to be opaque.
  readonly property color cardColor: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 1)
  readonly property color ink: Color.foreground
  readonly property color dim: Qt.darker(Color.foreground, 1.4)
  readonly property int pad: Style.spacing.panelPadding

  function methodCaption(row) {
    var kind = String(row && row.credentialKind || "")
    if (kind === "cli") return "用官方 CLI 在浏览器里登录"
    if (kind === "key") return "粘贴 API 密钥"
    if (kind === "both") return "官方 CLI 登录，或粘贴 API 密钥"
    return ""
  }

  function toggleExpanded(id) {
    root.expandedId = root.expandedId === id ? "" : id
  }

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
        if (root.formOpen) root.cancelActive()
        else root.requestClose()
        event.accepted = true
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0
        Component.onCompleted: opacity = 0.55
        Behavior on opacity { NumberAnimation { duration: 180 } }

        MouseArea {
          anchors.fill: parent
          onClicked: root.requestClose()
        }
      }

      Rectangle {
        id: card
        readonly property real maxHeight: Math.max(240, parent.height - 96)
        width: Math.min(560, Math.max(320, parent.width - 64))
        height: Math.min(card.maxHeight, head.height + list.contentHeight + root.pad * 2 + Style.spacing.panelGap)
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: root.cardColor
        border.width: 1
        border.color: Color.popups.border
        clip: true

        opacity: 0
        scale: 0.97
        Component.onCompleted: { opacity = 1; scale = 1 }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
          anchors.fill: parent
          onClicked: function(mouse) { mouse.accepted = true }
        }

        Column {
          id: head
          x: root.pad
          y: root.pad
          width: card.width - root.pad * 2
          spacing: Style.spacing.panelGap

          Item {
            width: parent.width
            height: Math.max(titleCol.implicitHeight, closeButton.implicitHeight)

            Text {
              id: gear
              anchors.verticalCenter: parent.verticalCenter
              text: ""
              color: Color.accent
              font.family: Style.font.resolvedFamily
              font.pixelSize: Style.font.display
            }

            Column {
              id: titleCol
              anchors.left: gear.right
              anchors.leftMargin: Style.space(14)
              anchors.right: closeButton.left
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: "PUB 设置"
                color: root.ink
                font.family: Style.font.resolvedFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }
              Text {
                width: parent.width
                text: root.showEditors
                  ? "AM01S 副屏 · " + root.enabledCount + " / " + root.providerCount + " 个 Provider 显示中"
                  : "AM01S 副屏"
                color: root.dim
                font.family: Style.font.resolvedFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                textFormat: Text.PlainText
              }
            }

            Button {
              id: closeButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: ""
              tooltipText: "关闭 (Esc)"
              onClicked: root.requestClose()
            }
          }

          Banner {
            text: root.message
            urgent: root.messageUrgent
          }

          Banner {
            text: root.notice
            urgent: root.noticeUrgent
          }

          Column {
            width: parent.width
            visible: root.showEditors
            spacing: Style.spacing.rowGap

            PanelSectionHeader { text: "显示" }

            Item {
              width: parent.width
              height: Math.max(modeLabel.implicitHeight, modeGroup.implicitHeight)

              Column {
                id: modeLabel
                anchors.left: parent.left
                anchors.right: modeGroup.left
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: "百分比读法"
                  color: root.ink
                  font.family: Style.font.resolvedFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }
                Text {
                  width: parent.width
                  text: root.remainingMode ? "Level Bar 越满，剩得越多" : "Level Bar 越满，用得越多"
                  color: root.dim
                  font.family: Style.font.resolvedFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }
              }

              ButtonGroup {
                id: modeGroup
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                focusable: false
                options: [{ value: "remaining", label: "剩余" }, { value: "used", label: "已用" }]
                value: root.remainingMode ? "remaining" : "used"
                onChanged: function(value) {
                  var on = value === "remaining"
                  if (on !== root.remainingMode) root.remainingModeToggled(on)
                }
              }
            }

            Item { width: 1; height: Style.spacing.md }
            PanelSeparator {}
            Item { width: 1; height: Style.spacing.md }

            Item {
              width: parent.width
              height: providerHeader.implicitHeight

              PanelSectionHeader {
                id: providerHeader
                text: "Provider"
              }
              Text {
                anchors.right: parent.right
                anchors.baseline: providerHeader.baseline
                text: "开关决定是否上副屏 · 点一行登录"
                color: root.dim
                font.family: Style.font.resolvedFamily
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
              }
            }
          }
        }

        Flickable {
          id: list
          visible: root.showEditors
          anchors.top: head.bottom
          anchors.topMargin: Style.spacing.rowGap
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.pad
          x: root.pad - Style.spacing.rowPaddingX
          width: card.width - (root.pad - Style.spacing.rowPaddingX) * 2
          clip: true
          contentWidth: width
          contentHeight: root.showEditors ? providerColumn.implicitHeight : 0
          flickableDirection: Flickable.VerticalFlick
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: providerColumn
            width: list.width

            Repeater {
              model: root.providers

              delegate: Column {
                id: row
                required property var modelData
                required property int index

                readonly property string pid: String(modelData.id || "")
                readonly property bool on: modelData.enabled === true
                readonly property bool signedOut: String(modelData.loginLabel || "").length > 0
                readonly property bool expanded: root.expandedId === row.pid
                readonly property bool showsForm: row.expanded && root.formOpen && root.activeId === row.pid

                width: providerColumn.width

                PanelSeparator { visible: row.index > 0; strength: 0.08 }

                Rectangle {
                  id: rowFace
                  width: parent.width
                  height: Math.max(Style.space(52), rowLine.implicitHeight + Style.space(16))
                  radius: Style.cornerRadius
                  color: rowHit.pressed ? Style.pressedFill
                    : rowHit.containsMouse ? Style.hoverFill
                    : row.expanded ? Style.normalFill : "transparent"
                  Behavior on color { ColorAnimation { duration: 120 } }

                  MouseArea {
                    id: rowHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleExpanded(row.pid)
                  }

                  Item {
                    id: rowLine
                    anchors.fill: parent
                    anchors.leftMargin: Style.spacing.rowPaddingX
                    anchors.rightMargin: Style.spacing.rowPaddingX
                    implicitHeight: nameCol.implicitHeight

                    Item {
                      id: mark
                      width: Style.space(28)
                      height: width
                      anchors.verticalCenter: parent.verticalCenter
                      opacity: row.on ? 1 : 0.45

                      Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Style.selectedFill
                      }
                      ProviderIcon {
                        id: markIcon
                        anchors.centerIn: parent
                        width: Style.space(18)
                        height: width
                        source: Qt.resolvedUrl("icons/" + row.pid + ".svg")
                        tint: root.ink
                        visible: markIcon.ready
                      }
                      Text {
                        anchors.centerIn: parent
                        visible: !markIcon.ready
                        text: String(row.modelData.name || row.pid).charAt(0).toUpperCase()
                        color: root.ink
                        font.family: Style.font.resolvedFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                      }
                    }

                    Column {
                      id: nameCol
                      anchors.left: mark.right
                      anchors.leftMargin: Style.space(12)
                      anchors.right: controls.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Text {
                        width: parent.width
                        text: row.modelData.name || row.pid
                        color: root.ink
                        opacity: row.on ? 1 : 0.6
                        font.family: Style.font.resolvedFamily
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                      }
                      Row {
                        spacing: Style.space(6)

                        Rectangle {
                          width: Style.space(6)
                          height: width
                          radius: width / 2
                          anchors.verticalCenter: parent.verticalCenter
                          color: row.signedOut ? Color.urgent : row.on ? Color.accent : Color.muted
                        }
                        Text {
                          text: row.signedOut ? row.modelData.loginLabel + " · 点开登录"
                            : row.on ? "显示在副屏" : "已隐藏"
                          color: row.signedOut ? Color.urgent : root.dim
                          font.family: Style.font.resolvedFamily
                          font.pixelSize: Style.font.caption
                          textFormat: Text.PlainText
                        }
                      }
                    }

                    Row {
                      id: controls
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)

                      Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(2)
                        opacity: rowHit.containsMouse || row.expanded || upButton.hot || downButton.hot ? 1 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Button {
                          id: upButton
                          iconText: ""
                          iconSize: Style.font.caption
                          tooltipText: "上移"
                          enabled: row.index > 0
                          opacity: enabled ? 1 : 0.3
                          onClicked: root.orderMoved(row.pid, -1)
                        }
                        Button {
                          id: downButton
                          iconText: ""
                          iconSize: Style.font.caption
                          tooltipText: "下移"
                          enabled: row.index < root.providerCount - 1
                          opacity: enabled ? 1 : 0.3
                          onClicked: root.orderMoved(row.pid, 1)
                        }
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(22)
                        horizontalAlignment: Text.AlignHCenter
                        text: ""
                        color: root.dim
                        font.family: Style.font.resolvedFamily
                        font.pixelSize: Style.font.caption
                        rotation: row.expanded ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                      }

                      ToggleSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: row.on
                        onToggled: root.enabledToggled(row.pid, !row.on)
                      }
                    }
                  }
                }

                Item {
                  width: parent.width
                  height: row.expanded ? drawer.implicitHeight : 0
                  clip: true
                  Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                  Column {
                    id: drawer
                    x: Style.spacing.rowPaddingX + Style.space(40)
                    width: parent.width - x - Style.spacing.rowPaddingX
                    topPadding: Style.space(4)
                    bottomPadding: Style.space(14)
                    spacing: Style.spacing.rowGap
                    opacity: row.expanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Text {
                      width: parent.width
                      visible: text.length > 0 && !row.showsForm
                      text: root.methodCaption(row.modelData)
                      color: root.dim
                      font.family: Style.font.resolvedFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.Wrap
                      textFormat: Text.PlainText
                    }

                    Flow {
                      width: parent.width
                      visible: !row.showsForm
                      spacing: Style.spacing.controlGap

                      Button {
                        visible: row.modelData.cli && String(row.modelData.cli.bin || "").length > 0
                        bordered: true
                        selected: row.modelData.credentialKind === "cli"
                        iconText: ""
                        text: row.modelData.credentialKind === "cli" ? "浏览器登录" : "用 CLI 登录"
                        onClicked: { root.expandedId = row.pid; root.beginCli(row.modelData) }
                      }
                      Button {
                        visible: row.modelData.page && String(row.modelData.page.url || "").length > 0
                        bordered: true
                        selected: row.modelData.credentialKind === "key" || row.modelData.credentialKind === "both"
                        iconText: ""
                        text: "打开 " + String(row.modelData.page && row.modelData.page.label ? row.modelData.page.label : "网页")
                        onClicked: { root.expandedId = row.pid; root.beginPage(row.modelData) }
                      }
                      Button {
                        bordered: true
                        iconText: ""
                        text: "粘贴密钥"
                        onClicked: { root.expandedId = row.pid; root.beginPaste(row.modelData) }
                      }
                      Button {
                        visible: row.modelData.clearOffered === true
                        bordered: true
                        foreground: Color.urgent
                        iconText: ""
                        text: "移除凭据"
                        onClicked: root.clearCredential(row.modelData)
                      }
                    }

                    Item {
                      id: formSlot
                      width: parent.width
                      visible: row.showsForm
                      height: row.showsForm ? loginForm.implicitHeight : 0
                    }

                    Binding {
                      target: loginForm
                      property: "parent"
                      value: formSlot
                      when: row.showsForm
                    }
                  }
                }
              }
            }
          }
        }

        // The login form has one instance; the open Provider row borrows it.
        Item {
          id: formPark
          visible: false

          Rectangle {
            id: loginForm
            width: parent ? parent.width : 0
            implicitHeight: formBody.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: Style.normalFill
            border.width: 1
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12)

            Column {
              id: formBody
              x: Style.space(12)
              y: Style.space(12)
              width: parent.width - Style.space(24)
              spacing: Style.spacing.rowGap

              Row {
                width: parent.width
                spacing: Style.space(8)

                Rectangle {
                  id: busyDot
                  width: Style.space(8)
                  height: width
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: root.codeRejected ? Color.urgent : Color.accent
                  SequentialAnimation on opacity {
                    running: root.cliActive || root.credActive
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) busyDot.opacity = 1
                    NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                  }
                }
                Text {
                  width: parent.width - busyDot.width - parent.spacing
                  text: root.activeMode === "cli" ? "官方 CLI 登录" : "粘贴密钥"
                  color: root.ink
                  font.family: Style.font.resolvedFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }
              }

              Text {
                width: parent.width
                visible: root.activeMode === "cli" && !(root.activeProvider && root.activeProvider.codeEntry)
                text: "在浏览器里完成登录，这里会自动刷新。"
                color: root.dim
                font.family: Style.font.resolvedFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
              }

              Text {
                width: parent.width
                visible: root.activeMode === "cli" && root.activeProvider && root.activeProvider.codeEntry && !root.codeSent
                text: "如果官方页面给出授权码，粘贴到下面。"
                color: root.dim
                font.family: Style.font.resolvedFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
              }

              TextField {
                id: codeField
                width: parent.width
                visible: root.activeMode === "cli" && root.activeProvider && root.activeProvider.codeEntry && !root.codeSent
                placeholderText: root.activeProvider && root.activeProvider.codeEntry ? String(root.activeProvider.codeEntry.hint || "") : ""
                foreground: root.ink
                accent: Color.accent
                font.family: Style.font.resolvedFamily
                onAccepted: root.submitCode(text)
              }

              Text {
                width: parent.width
                visible: root.activeMode === "cli" && root.codeSent && !root.codeRejected
                text: "正在验证授权码…"
                color: root.dim
                font.family: Style.font.resolvedFamily
                font.pixelSize: Style.font.caption
                textFormat: Text.PlainText
              }

              TextField {
                id: secretField
                width: parent.width
                visible: root.activeMode === "paste"
                password: true
                placeholderText: root.activeProvider ? String(root.activeProvider.hint || "") : ""
                foreground: root.ink
                accent: Color.accent
                font.family: Style.font.resolvedFamily
                onAccepted: {
                  if (extraField.visible) extraField.forceActiveFocus()
                  else root.savePaste()
                }
              }

              TextField {
                id: extraField
                width: parent.width
                visible: root.activeMode === "paste" && root.activeProvider && root.activeProvider.extra
                placeholderText: root.activeProvider && root.activeProvider.extra ? String(root.activeProvider.extra.hint || "") : ""
                foreground: root.ink
                accent: Color.accent
                font.family: Style.font.resolvedFamily
                onAccepted: root.savePaste()
              }

              Flow {
                width: parent.width
                spacing: Style.spacing.controlGap

                Button {
                  visible: root.authUrl.length > 0
                  bordered: true
                  iconText: ""
                  text: "打开授权页"
                  onClicked: root.openPage(root.authUrl)
                }
                Button {
                  visible: codeField.visible
                  bordered: true
                  selected: true
                  text: "提交授权码"
                  onClicked: root.submitCode(codeField.text)
                }
                Button {
                  visible: root.activeMode === "paste"
                  bordered: true
                  selected: true
                  text: root.credActive ? "保存中…" : "保存"
                  onClicked: root.savePaste()
                }
                Button {
                  visible: root.codeRejected
                  bordered: true
                  selected: true
                  text: "重新登录"
                  onClicked: if (root.activeProvider) root.beginCli(root.activeProvider)
                }
                Button {
                  bordered: true
                  text: "取消"
                  onClicked: root.cancelActive()
                }
              }
            }
          }
        }
      }
    }
  }

  component Banner: Rectangle {
    id: banner

    property string text: ""
    property bool urgent: false
    readonly property color tone: banner.urgent ? Color.urgent : Color.accent

    width: parent ? parent.width : 0
    visible: banner.text.length > 0
    height: bannerText.implicitHeight + Style.space(16)
    radius: Style.cornerRadius
    color: Qt.rgba(banner.tone.r, banner.tone.g, banner.tone.b, 0.12)

    Rectangle {
      width: Style.space(3)
      height: parent.height
      color: banner.tone
    }
    Text {
      id: bannerText
      x: Style.space(14)
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(24)
      text: banner.text
      color: banner.urgent ? Color.urgent : root.ink
      font.family: Style.font.resolvedFamily
      font.pixelSize: Style.font.body
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
    }
  }

  Process {
    id: pageProc
  }

  Process {
    id: cliProc
    stdinEnabled: false
    stdout: SplitParser {
      onRead: function(line) { root.onCliLine(line) }
    }
    stderr: SplitParser {
      onRead: function(line) { root.onCliLine(line) }
    }
    onExited: function(exitCode) {
      root.cliSawExit = true
      cliFailTimer.stop()
      var generation = root.cliGeneration
      var code = exitCode
      Qt.callLater(function() { root.finishCli(generation, code) })
    }
    onRunningChanged: {
      if (cliProc.running || !root.cliActive || root.cliSawExit) return
      cliFailTimer.generation = root.cliGeneration
      cliFailTimer.restart()
    }
  }

  Timer {
    id: cliFailTimer
    property int generation: 0
    interval: 200
    repeat: false
    onTriggered: root.finishCli(generation, 1)
  }

  Process {
    id: credProc
    property string pendingSecret: ""
    property string credStderr: ""
    stdinEnabled: false
    stdout: StdioCollector {
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: credErr
      waitForEnd: true
      onStreamFinished: credProc.credStderr = text
    }
    onStarted: {
      var body = credProc.pendingSecret
      credProc.pendingSecret = ""
      if (body.length > 0) credProc.write(body)
      if (credProc.stdinEnabled) credProc.stdinEnabled = false
    }
    onExited: function(exitCode) {
      root.credSawExit = true
      credFailTimer.stop()
      var generation = root.credGeneration
      var code = exitCode
      Qt.callLater(function() {
        var err = credProc.credStderr.length > 0 ? credProc.credStderr : credErr.text
        root.finishCred(generation, code, err)
      })
    }
    onRunningChanged: {
      if (credProc.running || !root.credActive || root.credSawExit) return
      credFailTimer.generation = root.credGeneration
      credFailTimer.restart()
    }
  }

  Timer {
    id: credFailTimer
    property int generation: 0
    interval: 200
    repeat: false
    onTriggered: root.finishCred(generation, 1, "")
  }
}
