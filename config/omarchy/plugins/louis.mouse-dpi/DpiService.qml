import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null

  property var devices: []
  property bool initialized: false

  readonly property var primary: Model.primary(devices)
  readonly property string compactDpi: Model.compactDpi(devices)
  readonly property string tooltipText: Model.tooltip(devices)

  readonly property string pluginDir:
    Quickshell.env("HOME") + "/.config/omarchy/plugins/louis.mouse-dpi"

  property bool refreshPending: false

  function refresh() {
    if (pollProc.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    pollProc.running = true
  }

  function applySnapshot(raw) {
    var parsed = Model.parseSnapshot(raw)
    if (parsed === null) return
    devices = parsed
    initialized = true
  }

  // Switch the mouse to a stage, then re-poll so the bar reflects the change.
  function setStage(index) {
    var device = root.primary
    if (!device || typeof index !== "number") return
    setProc.command = ["ratbagctl", device.id, "resolution", "active", "set", String(index)]
    setProc.running = true
  }

  function cycle() {
    var next = Model.nextIndex(root.primary)
    if (next !== null) setStage(next)
  }

  Component.onCompleted: refresh()

  Process {
    id: pollProc
    command: [root.pluginDir + "/poll"]
    onRunningChanged: {
      if (running) {
        stallTimer.restart()
        return
      }
      stallTimer.stop()
      if (root.refreshPending) root.refresh()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySnapshot(text)
    }
  }

  Process {
    id: setProc
    onRunningChanged: if (!running) root.refresh()
  }

  Timer {
    id: stallTimer
    interval: 10000
    onTriggered: pollProc.running = false
  }

  // The DPI button on the mouse changes state behind our back, so poll.
  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}
