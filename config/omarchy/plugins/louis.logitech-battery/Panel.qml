import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "louis.logitech-battery"
  ipcTarget: "louis.logitech-battery"

  property var anchorItem: null
  property var hostWidget: null
  property var deviceService: null
  readonly property var barIdentity: hostWidget || root

  readonly property var devices: deviceService ? Model.panelDevices(deviceService.devices) : []
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    if (deviceService) deviceService.refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(16)

        Text {
          text: "Logitech"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Repeater {
          model: root.devices

          delegate: Column {
            id: deviceCol
            required property var modelData
            width: column.width
            spacing: Style.space(6)

            readonly property bool live: modelData.present === true && typeof modelData.percentage === "number"
            readonly property bool charging: modelData.charging === true || modelData.state === "charging"
            readonly property bool low: Model.isLow(modelData, 20)
            readonly property color valueColor: !live ? root.dim : (low ? root.urgent : root.foreground)
            readonly property real fraction: live ? Math.max(0, Math.min(1, modelData.percentage / 100)) : 0

            Item {
              width: parent.width
              implicitHeight: Math.max(nameLabel.implicitHeight, pctLabel.implicitHeight)

              Text {
                id: nameLabel
                text: Model.iconFor(modelData.kind) + "  " + modelData.name
                color: deviceCol.valueColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.right: pctLabel.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: pctLabel
                text: Model.percentText(modelData)
                color: deviceCol.valueColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Item {
              width: parent.width
              implicitHeight: Style.space(8)

              Rectangle {
                id: track
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              }

              Rectangle {
                id: fill
                anchors.left: track.left
                anchors.verticalCenter: track.verticalCenter
                height: track.height
                radius: track.radius
                color: deviceCol.valueColor
                width: Math.max(deviceCol.live ? track.height : 0, track.width * deviceCol.fraction)
                opacity: deviceCol.live ? 1 : 0.35

                Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                SequentialAnimation {
                  running: deviceCol.charging && deviceCol.live && root.opened
                  loops: Animation.Infinite
                  alwaysRunToEnd: true
                  NumberAnimation { target: fill; property: "opacity"; from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
                  NumberAnimation { target: fill; property: "opacity"; from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
                  onRunningChanged: if (!running) fill.opacity = deviceCol.live ? 1 : 0.35
                }
              }
            }

            Text {
              text: Model.detailLine(modelData).toUpperCase()
              visible: Model.detailLine(modelData) !== ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.1
            }
          }
        }

        Text {
          visible: root.devices.length === 0
          text: "No wireless Logitech batteries reporting."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          width: parent.width
        }
      }
    }
  }
}
