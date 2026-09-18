import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "HuddleState.js" as HuddleState
import "BarGeometry.js" as BarGeometry
import "HuddleDraw.js" as HuddleDraw
import "IslesSettings.js" as IslesSettings

BarWidget {
  id: root
  moduleName: "io.github.inxeo.isles"

  readonly property bool opened: panelItem ? panelItem.opened === true : false
  function open() { if (panelItem) panelItem.open() }
  function close() { if (panelItem) panelItem.close() }
  function togglePanel() { if (panelItem) panelItem.toggle() }
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelItem) panelItem.closeForPopoutSwitch() }

  property var panelItem: null
  property var drawList: []
  property string lastDrawKey: ""

  readonly property var cfg: IslesSettings.fromSettings(settings)
  readonly property bool chrome: cfg.chrome
  readonly property bool edgeVertical: !!(bar && bar.vertical)
  readonly property int span: {
    if (bar && Number(bar.barSize) > 0) return Number(bar.barSize)
    return edgeVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  }
  readonly property var barLayer: {
    var w = root.QsWindow ? root.QsWindow.window : null
    return w && w.contentItem ? w.contentItem : null
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property int discoveryMisses: 0
  property bool discoveryWarning: false

  function discoverSlots() {
    var survey = BarGeometry.findSurfaceRoot(parent, root.barLayer, root.edgeVertical)
    var slots = BarGeometry.slotsIn(survey)
    if (!slots.length) {
      discoveryMisses++
      if (discoveryMisses >= 4 && !discoveryWarning) {
        console.warn("Isles: no compatible bar slots found; islands are hidden while discovery retries. Check Omarchy compatibility.")
        discoveryWarning = true
      }
    } else {
      discoveryMisses = 0
      discoveryWarning = false
    }
    return slots
  }

  function slotInkSize(slot) {
    var empty = { w: 0, h: 0 }
    if (!slot) return empty
    try {
      if (slot.visible === false) return empty
    } catch (e) {
      return empty
    }
    try {
      if (slot.activeItem !== undefined && slot.activeItem && slot.activeItem.visible === false)
        return empty
    } catch (e) {}

    var w = 0
    var h = 0
    try { w = Number(slot.width) || 0 } catch (e) {}
    try { h = Number(slot.height) || 0 } catch (e) {}
    if (w <= 0) {
      try {
        var item = slot.activeItem
        if (item) w = Number(item.width) || Number(item.implicitWidth) || 0
      } catch (e) {}
    }
    if (h <= 0) {
      try {
        var itemH = slot.activeItem
        if (itemH) h = Number(itemH.height) || Number(itemH.implicitHeight) || 0
      } catch (e) {}
    }
    return { w: w, h: h }
  }

  function measureHuddle() {
    if (!root.chrome) {
      if (root.drawList.length) {
        root.drawList = []
        root.lastDrawKey = ""
      }
      burstSettle.stop()
      return
    }

    var window = root.QsWindow ? root.QsWindow.window : null
    if (!window || !window.contentItem) return

    var slots = discoverSlots()
    if (!slots.length) {
      root.drawList = []
      root.lastDrawKey = ""
      return
    }

    var boxes = {
      left: { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity, found: false },
      center: { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity, found: false },
      right: { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity, found: false }
    }
    var order = ["left", "center", "right"]
    var slotRects = []
    var conf = root.cfg

    for (var i = 0; i < slots.length; i++) {
      var slot = slots[i]
      var region = ""
      try { region = String(slot.region || "") } catch (e) { continue }
      var box = boxes[region]
      if (!box) continue
      var ink = slotInkSize(slot)
      if (ink.w <= 0 || ink.h <= 0) continue
      var origin
      try {
        origin = slot.mapToItem(window.contentItem, 0, 0)
      } catch (e) {
        continue
      }
      if (!origin) continue
      box.found = true
      box.minX = Math.min(box.minX, origin.x)
      box.minY = Math.min(box.minY, origin.y)
      box.maxX = Math.max(box.maxX, origin.x + ink.w)
      box.maxY = Math.max(box.maxY, origin.y + ink.h)
      slotRects.push({
        x: Math.round(origin.x),
        y: Math.round(origin.y),
        width: Math.round(ink.w),
        height: Math.round(ink.h),
        region: region
      })
    }

    var clusters = []
    for (var r = 0; r < order.length; r++) {
      var b = boxes[order[r]]
      if (!b.found) continue
      clusters.push({
        x: Math.round(b.minX),
        y: Math.round(b.minY),
        width: Math.round(b.maxX - b.minX),
        height: Math.round(b.maxY - b.minY),
        region: order[r]
      })
    }

    var payload = {
      look: conf.look,
      border: conf.border,
      padding: conf.padding,
      radius: conf.radius,
      opacity: conf.opacity,
      strokeOpacity: conf.strokeOpacity,
      strokeWidth: conf.strokeWidth,
      clusters: clusters,
      slots: slotRects
    }
    var key = HuddleState.keyOf(payload, window.contentItem.width, window.contentItem.height, span, edgeVertical)
    if (key === root.lastDrawKey) {
      return
    }
    root.lastDrawKey = key
    root.drawList = HuddleDraw.build(payload, window.contentItem.width, window.contentItem.height, span, edgeVertical)
    measureTimer.interval = 50
    burstSettle.restart()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    panelItem = target
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  Component.onCompleted: measureHuddle()
  onParentChanged: Qt.callLater(measureHuddle)
  onSpanChanged: Qt.callLater(measureHuddle)
  onEdgeVerticalChanged: Qt.callLater(measureHuddle)
  onBarLayerChanged: {
    root.lastDrawKey = ""
    root.drawList = []
    Qt.callLater(measureHuddle)
  }
  onBarChanged: {
    injectPanel()
    Qt.callLater(measureHuddle)
  }
  onSettingsChanged: {
    injectPanel()
    // The cache key already contains appearance settings. Preset names and
    // saved collections do not require rebuilding the rendering objects.
    Qt.callLater(measureHuddle)
  }
  onChromeChanged: {
    root.lastDrawKey = ""
    Qt.callLater(measureHuddle)
  }

  Connections {
    target: root.barLayer
    function onWidthChanged() { Qt.callLater(root.measureHuddle) }
    function onHeightChanged() { Qt.callLater(root.measureHuddle) }
  }

  Timer {
    id: measureTimer
    interval: 250
    running: root.chrome
    repeat: true
    onTriggered: root.measureHuddle()
  }

  Timer {
    id: burstSettle
    interval: 400
    onTriggered: measureTimer.interval = 250
  }

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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf1fb"
    tooltipText: root.opened ? "Close Isles" : "Isles"

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }

  // Paint in the bar window, under the widgets. A separate Bottom layer
  // sat on top of left/right bars and made icons look washed out.
  Item {
    id: chromeHost
    parent: root.barLayer
    z: -1000
    anchors.fill: parent
    visible: root.chrome
    enabled: false
    clip: true

    Repeater {
      model: root.drawList

      Item {
        id: piece
        required property var modelData
        required property int index

        readonly property real fillInk: {
          var row = root.drawList[index]
          var n = row ? Number(row.fillAlpha) : NaN
          return isFinite(n) ? n : 0.62
        }
        readonly property real strokeInk: {
          var row = root.drawList[index]
          var n = row ? Number(row.strokeAlpha) : NaN
          return isFinite(n) ? n : 1
        }

        visible: Number(modelData.width) > 0 && Number(modelData.height) > 0
        x: Number(modelData.x) || 0
        y: Number(modelData.y) || 0
        width: Number(modelData.width) || 0
        height: Number(modelData.height) || 0

        Loader {
          anchors.fill: parent
          sourceComponent: piece.modelData.kind === "power" ? powerRenderer
            : piece.modelData.kind === "bracket" ? bracketRenderer : boxRenderer
        }

        Component {
          id: boxRenderer
          ChromeBox {
            anchors.fill: parent
            edge: String(piece.modelData.pointed ? "ends" : (piece.modelData.border || "none"))
            glow: piece.modelData.glow === true
            pointed: piece.modelData.pointed === true
            vertical: root.edgeVertical
            roundness: Number(piece.modelData.radius)
            fillAlpha: piece.fillInk
            strokeAlpha: piece.strokeInk
            px: Number(piece.modelData.strokeWidth)
          }
        }

        Component {
          id: powerRenderer
          PowerSeg {
            anchors.fill: parent
            first: piece.modelData.first === true
            vertical: root.edgeVertical
            fillAlpha: piece.fillInk
            strokeAlpha: piece.strokeInk
            px: Number(piece.modelData.strokeWidth)
          }
        }

        Component {
          id: bracketRenderer
          BracketChrome {
            anchors.fill: parent
            fillAlpha: piece.fillInk
            strokeAlpha: piece.strokeInk
            px: Number(piece.modelData.strokeWidth)
          }
        }
      }
    }
  }
}
