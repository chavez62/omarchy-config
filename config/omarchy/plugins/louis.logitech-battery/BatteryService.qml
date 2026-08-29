import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH") || ""

  property var devices: []
  property bool initialized: false

  readonly property var liveDevices: Model.liveDevices(devices)
  readonly property var items: Model.barItems(devices, false)
  readonly property string compactPercent: Model.compactPercent(devices)
  readonly property bool compactUrgent: Model.compactUrgent(devices)
  readonly property bool anyLow: Model.anyLow(devices, 20)
  readonly property string tooltipText: Model.tooltip(devices)

  readonly property string notifyBin: omarchyPath !== ""
    ? omarchyPath + "/bin/omarchy-notification-send"
    : "omarchy-notification-send"

  property bool refreshPending: false

  PersistentProperties {
    id: persisted
    reloadableId: "louis.logitech-battery"
    property string notifiedJson: "{}"
  }

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
    checkNotify()
  }

  function parseNotified() {
    try {
      return JSON.parse(persisted.notifiedJson || "{}")
    } catch (e) {
      return {}
    }
  }

  function checkNotify() {
    var plan = Model.applyNotices(devices, parseNotified())
    persisted.notifiedJson = JSON.stringify(plan.notified || {})
    var notices = plan.notices || []
    for (var i = 0; i < notices.length; i++) sendNotice(notices[i])
  }

  function sendNotice(notice) {
    if (!notice) return
    var urgency = notice.urgency === "critical" ? "critical" : "normal"
    var body = notice.threshold <= 10 ? "Charge it soon." : "Getting low."
    Quickshell.execDetached([
      notifyBin,
      "--app-name", "Logitech",
      "-u", urgency,
      "-g", Model.iconFor(notice.kind),
      notice.name + " battery " + notice.percentage + "%",
      body
    ])
  }

  Component.onCompleted: {
    refresh()
  }

  Process {
    id: pollProc
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/louis.logitech-battery/poll"]
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

  Timer {
    id: stallTimer
    interval: 10000
    onTriggered: headsetProc.running = false
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}
