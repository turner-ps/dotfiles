import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "steventurner.chillhop"
  ipcTarget: "steventurner.chillhop"

  readonly property string controlPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/steventurner.chillhop/chillhop-control"
  readonly property string iconPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/steventurner.chillhop/assets/chillhop-bar.png"

  property bool streamRunning: false
  property bool streamPaused: false
  property bool streamStalled: false
  property bool streamLoading: false
  property string lastError: ""
  property int selectedAction: 0
  property bool returnActivatesCursor: false

  readonly property string barIcon: streamPaused ? "󰐊" : "󰏤"
  readonly property string heroStatus: streamLoading ? "Loading" : (!streamRunning ? "Ready" : (streamPaused ? "Paused" : "Live"))
  readonly property string actionLabel: !streamRunning ? "Start" : (streamPaused ? "Resume" : "Pause")
  readonly property string actionIcon: !streamRunning || streamPaused ? "󰐊" : "󰏤"

  function parseStatus(raw) {
    var text = String(raw || "").trim()
    if (!text) return
    var lines = text.split("\n")
    var data = null
    try {
      data = JSON.parse(lines[lines.length - 1])
    } catch (e) {
      lastError = text
      return
    }
    streamStalled = data.stalled === true
    streamLoading = data.loading === true
    streamRunning = data.running === true && !streamStalled
    streamPaused = data.paused === true && streamRunning
    lastError = ""
    clampCursor()
  }

  function runControl(action) {
    if (controlProc.running) return
    controlProc.command = [controlPath, action]
    controlProc.running = true
  }

  function refreshStatus() {
    if (statusProc.running) return
    statusProc.command = [controlPath, "status"]
    statusProc.running = true
  }

  function primaryAction() {
    if (!streamRunning || streamPaused) runControl("start")
    else runControl("pause")
  }

  function actionEnabled(index) {
    return true
  }

  function moveCursor(dx, dy) {
    var delta = dx !== 0 ? dx : dy
    if (delta === 0) return
    var next = selectedAction
    for (var i = 0; i < 2; i++) {
      next = (next + delta + 2) % 2
      if (actionEnabled(next)) {
        selectedAction = next
        return
      }
    }
  }

  function clampCursor() {
    if (!actionEnabled(selectedAction)) moveCursor(1, 0)
  }

  function activateCursor() {
    if (selectedAction === 0) primaryAction()
    else if (selectedAction === 1) runControl("open-youtube")
  }

  onOpenedChanged: {
    refreshStatus()
    if (opened) selectedAction = 0
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: controlProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.lastError = String(text).trim()
    }
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.streamRunning ? root.barIcon : ""
    iconComponent: root.streamRunning ? null : chillhopBarIcon
    opticalSize: Style.space(16)
    active: root.streamRunning && !root.streamPaused
    tooltipText: "Chillhop Radio: " + root.heroStatus
    onPressed: function(b) {
      if (b === Qt.RightButton) root.primaryAction()
      else root.toggle()
    }
  }

  Component {
    id: chillhopBarIcon
    Image {
      anchors.centerIn: parent
      width: parent.width
      height: parent.height
      source: Util.fileUrl(root.iconPath)
      fillMode: Image.PreserveAspectFit
      asynchronous: false
      cache: false
      smooth: true
      mipmap: true
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onReturnRequested: root.returnActivatesCursor = true
      onActivateRequested: {
        if (root.returnActivatesCursor) {
          root.returnActivatesCursor = false
          root.activateCursor()
        } else {
          root.primaryAction()
        }
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Item {
            id: heroIcon
            width: Style.space(42)
            height: Style.space(42)
            opacity: root.streamRunning ? 1.0 : 0.55
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Image {
              visible: !root.streamRunning
              anchors.fill: parent
              source: Util.fileUrl(root.iconPath)
              fillMode: Image.PreserveAspectFit
              asynchronous: false
              cache: false
              smooth: true
              mipmap: true
            }

            Text {
              visible: root.streamRunning
              anchors.centerIn: parent
              text: root.barIcon
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Chillhop Radio"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: (root.heroStatus + " from YouTube").toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Flow {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: root.actionLabel
            iconText: root.actionIcon
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            hasCursor: root.selectedAction === 0
            onHovered: function(on) { if (on) root.selectedAction = 0 }
            onClicked: root.primaryAction()
          }

          Button {
            text: "Open on YouTube"
            iconText: "󰗃"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            hasCursor: root.selectedAction === 1
            onHovered: function(on) { if (on) root.selectedAction = 1 }
            onClicked: root.runControl("open-youtube")
          }
        }

        Text {
          text: root.streamRunning
            ? "SPACE plays or pauses. ENTER activates the highlighted action. Arrow keys or h/j/k/l move between actions. ESC closes this panel."
            : "Start the stream to listen to the Chillhop live channel."
          color: Qt.darker(root.bar.foreground, 1.45)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Text {
          visible: root.lastError !== ""
          text: root.lastError
          color: root.bar.urgent
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          width: parent.width
        }
      }
    }
  }
}
