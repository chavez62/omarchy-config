import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "louis.logitech-battery"

  readonly property var deviceService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var devices: deviceService ? deviceService.devices : []
  readonly property bool showPercentage: setting("showPercentage", false) === true
  readonly property var items: Model.barItems(devices, showPercentage)
  readonly property bool anyLow: Model.anyLow(devices, 20)
  readonly property bool serviceReady: !!deviceService && deviceService.initialized === true

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: content.implicitWidth
  readonly property real openPanelIndicatorHeight: content.implicitHeight

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("deviceService" in target) target.deviceService = root.deviceService
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function refresh() { if (deviceService) deviceService.refresh() }
  function togglePercentage() {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.showPercentage = !root.showPercentage
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  visible: serviceReady && items.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: Qt.callLater(injectPanel)
  onSettingsChanged: Qt.callLater(injectPanel)
  onDeviceServiceChanged: Qt.callLater(injectPanel)
  Component.onCompleted: Qt.callLater(injectPanel)

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: root.items.length > 0
    tooltipText: deviceService ? deviceService.tooltipText : ""
    active: root.anyLow
    horizontalMargin: 8
    fixedWidth: root.vertical ? -1 : Math.round(content.implicitWidth + scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.round(content.implicitHeight + scaledVerticalPadding * 2) : -1

    onPressed: function(b) {
      if (b === Qt.RightButton) root.togglePercentage()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    Grid {
      id: content
      anchors.centerIn: parent
      rows: root.vertical ? Math.max(1, root.items.length) : 1
      columns: root.vertical ? 1 : Math.max(1, root.items.length)
      flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
      rowSpacing: Style.space(2)
      columnSpacing: Style.space(6)

      Repeater {
        model: root.items

        delegate: Row {
          required property var modelData
          spacing: Style.space(3)

          readonly property color itemColor: modelData.low
            ? (button.bar ? button.bar.urgent : Color.urgent)
            : button.foreground

          OpticalGlyph {
            width: Style.bar.iconCanvas
            height: Style.bar.iconCanvas
            text: modelData.charging ? "󰂄" : modelData.icon
            fontFamily: button.fontFamily
            fontSize: Style.bar.iconFont
            color: parent.itemColor
          }

          Text {
            visible: root.showPercentage && !root.vertical
            text: modelData.percentText
            color: parent.itemColor
            font.family: button.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            height: Style.bar.iconCanvas
          }
        }
      }
    }
  }

  // The bar overlay only dispatches left clicks. WidgetButton's MouseArea
  // sits under the icons, so right/middle clicks on the glyphs never arrive.
  MouseArea {
    anchors.fill: parent
    z: 100
    acceptedButtons: Qt.RightButton | Qt.MiddleButton
    hoverEnabled: false
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.togglePercentage()
      else if (mouse.button === Qt.MiddleButton) root.refresh()
    }
  }
}
