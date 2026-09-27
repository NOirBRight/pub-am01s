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

  readonly property string formTitle: {
    var row = root.activeProvider
    if (!row) return ""
    var name = String(row.name || row.id || "")
    if (root.activeMode === "cli") return name + " · 官方 CLI"
    if (root.activeMode === "paste") return name + " · 粘贴密钥"
    return name
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

          Text {
            width: parent.width
            visible: root.notice.length > 0
            text: root.notice
            color: root.noticeUrgent ? Color.urgent : Color.menu.text
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

              Column {
                id: loginForm
                width: parent.width
                visible: root.activeMode === "cli" || root.activeMode === "paste"
                spacing: 8

                Text {
                  width: parent.width
                  text: root.formTitle
                  color: Color.menu.text
                  font.family: Style.font.resolvedFamily
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }

                Text {
                  width: parent.width
                  visible: root.activeMode === "cli" && !(root.activeProvider && root.activeProvider.codeEntry)
                  text: "正在等待官方 CLI 结束。"
                  color: Color.menu.text
                  font.family: Style.font.resolvedFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                  textFormat: Text.PlainText
                }

                Text {
                  width: parent.width
                  visible: root.activeMode === "cli" && root.activeProvider && root.activeProvider.codeEntry && !root.codeSent
                  text: "如果官方页面给出授权码，粘贴到下面。"
                  color: Color.menu.text
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
                  foreground: Color.menu.text
                  accent: Color.accent
                  font.family: Style.font.resolvedFamily
                  onAccepted: root.submitCode(text)
                }

                Text {
                  width: parent.width
                  visible: root.activeMode === "cli" && root.codeSent && !root.codeRejected
                  text: "正在验证授权码…"
                  color: Color.menu.text
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
                  foreground: Color.menu.text
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
                  foreground: Color.menu.text
                  accent: Color.accent
                  font.family: Style.font.resolvedFamily
                  onAccepted: root.savePaste()
                }

                Flow {
                  width: parent.width
                  spacing: 6

                  LoginButton {
                    visible: root.authUrl.length > 0
                    label: "打开授权页"
                    onClicked: root.openPage(root.authUrl)
                  }

                  LoginButton {
                    visible: codeField.visible
                    primary: true
                    label: "提交授权码"
                    onClicked: root.submitCode(codeField.text)
                  }

                  LoginButton {
                    visible: root.activeMode === "paste"
                    primary: true
                    label: "保存"
                    onClicked: root.savePaste()
                  }

                  LoginButton {
                    visible: root.codeRejected
                    primary: true
                    label: "重新登录"
                    onClicked: if (root.activeProvider) root.beginCli(root.activeProvider)
                  }

                  LoginButton {
                    label: "取消"
                    onClicked: root.cancelActive()
                  }
                }
              }

              Repeater {
                model: root.providers

                delegate: Rectangle {
                  id: row
                  required property var modelData
                  required property int index

                  width: providerColumn.width
                  height: rowBody.implicitHeight + 16
                  radius: 10
                  color: Color.menu.selectedBackground

                  Column {
                    id: rowBody
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 14
                    anchors.topMargin: 8
                    spacing: 6

                    Row {
                      width: parent.width
                      height: 36
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

                        MouseArea {
                          anchors.fill: parent
                          onClicked: root.enabledToggled(String(modelData.id || ""), modelData.enabled !== true)
                        }
                      }
                    }

                    Flow {
                      width: parent.width
                      spacing: 6

                      LoginButton {
                        visible: modelData.cli && String(modelData.cli.bin || "").length > 0
                        primary: modelData.credentialKind === "cli"
                        label: modelData.credentialKind === "cli" ? "浏览器登录" : "用 CLI 登录"
                        onClicked: root.beginCli(modelData)
                      }

                      LoginButton {
                        visible: modelData.page && String(modelData.page.url || "").length > 0
                        primary: modelData.credentialKind === "key" || modelData.credentialKind === "both"
                        label: "打开 " + String(modelData.page && modelData.page.label ? modelData.page.label : "网页")
                        onClicked: root.beginPage(modelData)
                      }

                      LoginButton {
                        label: "粘贴密钥"
                        onClicked: root.beginPaste(modelData)
                      }

                      LoginButton {
                        visible: modelData.clearOffered === true
                        label: "移除凭据"
                        onClicked: root.clearCredential(modelData)
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
  }

  component LoginButton: Rectangle {
    id: button

    property string label: ""
    property bool primary: false
    signal clicked()

    width: buttonLabel.implicitWidth + 20
    height: 28
    radius: 8
    color: primary ? Color.accent : Color.menu.background
    border.width: primary ? 0 : 1
    border.color: Color.menu.border

    Text {
      id: buttonLabel
      anchors.centerIn: parent
      text: button.label
      color: button.primary ? Color.menu.selectedText : Color.menu.text
      font.family: Style.font.resolvedFamily
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }

    MouseArea {
      anchors.fill: parent
      onClicked: button.clicked()
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
