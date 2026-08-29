import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "louis.mouse-dpi"

  readonly property var dpiService: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var devices: dpiService ? dpiService.devices : []
  readonly property var primary: Model.primary(devices)
  readonly property bool showLabel: setting("showLabel", true) === true
  readonly property bool serviceReady: !!dpiService && dpiService.initialized === true

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
    if ("dpiService" in target) target.dpiService = root.dpiService
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function cycle() { if (dpiService) dpiService.cycle() }
  function refresh() { if (dpiService) dpiService.refresh() }

  visible: serviceReady && !!primary
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: Qt.callLater(injectPanel)
  onSettingsChanged: Qt.callLater(injectPanel)
  onDpiServiceChanged: Qt.callLater(injectPanel)
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
    hasVisualContent: !!root.primary
    tooltipText: dpiService ? dpiService.tooltipText : ""
    horizontalMargin: 8
    fixedWidth: root.vertical ? -1 : Math.round(content.implicitWidth + scaledHorizontalMargin * 2)
    fixedHeight: root.vertical ? Math.round(content.implicitHeight + scaledVerticalPadding * 2) : -1

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycle()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }

    Grid {
      id: content
      anchors.centerIn: parent
      rows: root.vertical ? 2 : 1
      columns: root.vertical ? 1 : 2
      flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
      rowSpacing: Style.space(2)
      columnSpacing: Style.space(3)

      OpticalGlyph {
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        text: "󰓅"
        fontFamily: button.fontFamily
        fontSize: Style.bar.iconFont
        color: button.foreground
      }

      Text {
        visible: root.showLabel && !root.vertical
        text: Model.dpiText(root.primary)
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        verticalAlignment: Text.AlignVCenter
        height: Style.bar.iconCanvas
      }
    }
  }

  // The bar overlay only dispatches left clicks; mirror the battery widget's
  // trick so right/middle clicks on the glyph still register.
  MouseArea {
    anchors.fill: parent
    z: 100
    acceptedButtons: Qt.RightButton | Qt.MiddleButton
    hoverEnabled: false
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.cycle()
      else if (mouse.button === Qt.MiddleButton) root.refresh()
    }
  }
}
