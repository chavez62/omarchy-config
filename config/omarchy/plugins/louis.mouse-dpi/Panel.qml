import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "louis.mouse-dpi"
  ipcTarget: "louis.mouse-dpi"

  property var anchorItem: null
  property var hostWidget: null
  property var dpiService: null
  readonly property var barIdentity: hostWidget || root

  readonly property var device: dpiService ? Model.primary(dpiService.devices) : null
  readonly property var stages: Model.stagesFor(device)
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    if (dpiService) dpiService.refresh()
  }

  function close() { root.controller.hide() }

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
    contentWidth: panel.fittedContentWidth(Style.space(300))
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
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(title.implicitHeight, rateLabel.implicitHeight)

          Text {
            id: title
            text: root.device ? root.device.name : "Mouse DPI"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
            anchors.left: parent.left
            anchors.right: rateLabel.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: rateLabel
            text: Model.rateText(root.device)
            visible: text !== ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: root.stages

            delegate: Item {
              id: stageRow
              required property var modelData
              width: column.width
              implicitHeight: Style.space(30)

              readonly property bool active: modelData.active === true
              readonly property color rowColor: active ? root.accent : root.foreground

              Rectangle {
                anchors.fill: parent
                radius: Style.space(6)
                color: hover.hovered
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
                  : "transparent"
              }

              // Relative-width bar behind the numbers, so the stages read as a ramp.
              Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height - Style.space(8)
                radius: Style.space(4)
                width: Math.max(height, (parent.width) * Model.fraction(stageRow.modelData, root.stages))
                color: stageRow.rowColor
                opacity: stageRow.active ? 0.22 : 0.08

                Behavior on opacity { NumberAnimation { duration: 160 } }
              }

              Text {
                text: stageRow.modelData.dpi + " DPI"
                color: stageRow.rowColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: stageRow.active
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: stageRow.active ? "●" : (stageRow.modelData.isDefault ? "default" : "")
                color: stageRow.active ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
              }

              HoverHandler { id: hover }

              TapHandler {
                onTapped: {
                  if (root.dpiService) root.dpiService.setStage(stageRow.modelData.index)
                }
              }
            }
          }
        }

        Text {
          text: "CLICK A STAGE TO SWITCH  ·  RIGHT-CLICK BAR TO CYCLE"
          visible: root.stages.length > 0
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.1
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Text {
          visible: !root.device
          text: "No libratbag mouse detected. Is ratbagd running?"
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
