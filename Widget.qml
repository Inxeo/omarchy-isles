import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "HuddleState.js" as HuddleState
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

  // Walk to the full-width bar surface, then union ink per section so one
  // chip (anywhere) can chrome left, center, and right.
  function findBarRoot() {
    var window = root.QsWindow ? root.QsWindow.window : null
    var item = window && window.contentItem ? window.contentItem : null
    if (!item) return null
    var vertical = !!(root.bar && root.bar.vertical)
    var alongSpan = vertical ? Number(item.height) : Number(item.width)
    var p = parent
    var best = null
    while (p) {
      var along = vertical ? Number(p.height) : Number(p.width)
      if (alongSpan > 0 && along > alongSpan * 0.9) best = p
      p = p.parent
    }
    return best
  }

  function gatherSlots(item, acc) {
    if (!item) return
    try {
      if (item.visible === false) return
    } catch (e) {
      return
    }
    var region = ""
    var name = ""
    try {
      if (item.region !== undefined) region = String(item.region)
      if (item.moduleName !== undefined) name = String(item.moduleName)
    } catch (e) {}
    if ((region === "left" || region === "center" || region === "right") && name)
      acc.push(item)
    var kids
    try {
      kids = item.children
    } catch (e) {
      return
    }
    if (!kids) return
    for (var i = 0; i < kids.length; i++) gatherSlots(kids[i], acc)
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
      measureTimer.interval = 1000
      return
    }

    var window = root.QsWindow ? root.QsWindow.window : null
    if (!window || !window.contentItem) return

    var survey = findBarRoot()
    if (!survey) {
      if (root.drawList.length) {
        root.drawList = []
        root.lastDrawKey = ""
      }
      return
    }

    var slots = []
    gatherSlots(survey, slots)

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
      barWidth: Math.round(Number(window.contentItem.width) || 0),
      clusters: clusters,
      slots: slotRects
    }
    var key = HuddleState.keyOf(payload)
    if (key === root.lastDrawKey) {
      if (measureTimer.interval === 50)
        burstSettle.restart()
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
  onBarChanged: {
    injectPanel()
    Qt.callLater(measureHuddle)
  }
  onSettingsChanged: {
    injectPanel()
    root.lastDrawKey = ""
    Qt.callLater(measureHuddle)
  }
  onChromeChanged: {
    root.lastDrawKey = ""
    Qt.callLater(measureHuddle)
  }

  Timer {
    id: measureTimer
    interval: 250
    running: true
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

        ChromeBox {
          anchors.fill: parent
          visible: String(piece.modelData.kind) === "box"
          edge: String(piece.modelData.pointed ? "ends" : (piece.modelData.border || "none"))
          glow: piece.modelData.glow === true
          pointed: piece.modelData.pointed === true
          vertical: root.edgeVertical
          roundness: Number(piece.modelData.radius)
          fillAlpha: piece.fillInk
          strokeAlpha: piece.strokeInk
          px: Number(piece.modelData.strokeWidth)
        }

        PowerSeg {
          anchors.fill: parent
          visible: String(piece.modelData.kind) === "power"
          first: piece.modelData.first === true
          vertical: root.edgeVertical
          fillAlpha: piece.fillInk
          strokeAlpha: piece.strokeInk
          px: Number(piece.modelData.strokeWidth)
        }

        BracketChrome {
          anchors.fill: parent
          visible: String(piece.modelData.kind) === "bracket"
          fillAlpha: piece.fillInk
          strokeAlpha: piece.strokeInk
          px: Number(piece.modelData.strokeWidth)
        }
      }
    }
  }
}
