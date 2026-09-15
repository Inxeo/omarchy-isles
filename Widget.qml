import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "HuddleState.js" as HuddleState
import "HuddleDraw.js" as HuddleDraw

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

  readonly property bool edgeVertical: !!(bar && bar.vertical)
  readonly property int span: {
    if (bar && Number(bar.barSize) > 0) return Number(bar.barSize)
    return edgeVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  }
  readonly property var barLayer: {
    var w = root.QsWindow ? root.QsWindow.window : null
    return w && w.contentItem ? w.contentItem : null
  }

  readonly property bool chrome: setting("chrome", true) !== false
  readonly property int opacityPct: Number(setting("opacity", 62))
  readonly property int strokeOpacityPct: {
    var n = Number(setting("strokeOpacity", 100))
    return isFinite(n) ? n : 100
  }
  readonly property int padding: Number(setting("padding", 8))
  readonly property int radius: Number(setting("radius", 100))
  readonly property string look: {
    var l = String(setting("look", "cluster") || "cluster")
    if (l === "pills" || l === "rail" || l === "power" || l === "brackets" || l === "glow")
      return l
    return "cluster"
  }
  readonly property int strokeWidthPx: {
    var n = Number(setting("strokeWidth", -1))
    if (isFinite(n) && n >= 0) return Math.max(0, Math.min(5, Math.round(n)))
    var b = setting("border", "all")
    if (b === false || b === "false" || b === "none") return 0
    return 1
  }
  readonly property string borderStyle: {
    var b = setting("border", "all")
    if (b === true || b === "true" || b === "all") return "all"
    if (b === "bottom") return "bottom"
    if (b === "top") return "top"
    if (b === "horiz") return "horiz"
    if (b === "sides") return "sides"
    if (b === "ends") return "ends"
    return "all"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Walk to the full-width bar surface, then union ink per section so one
  // chip (anywhere) can chrome left, center, and right.
  function findBarRoot() {
    var window = root.QsWindow ? root.QsWindow.window : null
    var item = window && window.contentItem ? window.contentItem : null
    var vertical = !!(root.bar && root.bar.vertical)
    var span = item ? (vertical ? Number(item.height) : Number(item.width)) : 0
    var p = parent
    var best = null
    while (p) {
      var along = vertical ? Number(p.height) : Number(p.width)
      if (span > 0 && along > span * 0.9) best = p
      p = p.parent
    }
    return best
  }

  function gatherSlots(item, acc) {
    if (!item || item.visible === false) return
    var region = item.region !== undefined ? String(item.region) : ""
    var name = item.moduleName !== undefined ? String(item.moduleName) : ""
    if ((region === "left" || region === "center" || region === "right") && name)
      acc.push(item)
    var kids = item.children
    if (!kids) return
    for (var i = 0; i < kids.length; i++) gatherSlots(kids[i], acc)
  }

  function slotInkWidth(slot) {
    if (!slot || slot.visible === false) return 0
    var item = slot.activeItem
    if (item && item.visible === false) return 0
    if (item) {
      var iw = Number(item.implicitWidth) || 0
      if (iw > 0) return iw
    }
    return Number(slot.width) || 0
  }

  function measureHuddle() {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screenName = window && window.screen ? String(window.screen.name) : ""
    if (!window || !window.contentItem || !chrome || !screenName) {
      if (screenName) HuddleState.report(screenName, null)
      return
    }

    var survey = findBarRoot()
    var slots = []
    gatherSlots(survey, slots)

    var boxes = {
      left: { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity, found: false },
      center: { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity, found: false },
      right: { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity, found: false }
    }
    var order = ["left", "center", "right"]
    var slotRects = []

    for (var i = 0; i < slots.length; i++) {
      var slot = slots[i]
      var region = String(slot.region || "")
      var box = boxes[region]
      if (!box) continue
      var w = slotInkWidth(slot)
      if (w <= 0) continue
      var h = Number(slot.height) || Number(slot.implicitHeight) || 0
      if (h <= 0) h = root.barSize
      var origin
      try {
        origin = slot.mapToItem(window.contentItem, 0, 0)
      } catch (e) {
        continue
      }
      box.found = true
      box.minX = Math.min(box.minX, origin.x)
      box.minY = Math.min(box.minY, origin.y)
      box.maxX = Math.max(box.maxX, origin.x + w)
      box.maxY = Math.max(box.maxY, origin.y + h)
      slotRects.push({
        x: Math.round(origin.x),
        y: Math.round(origin.y),
        width: Math.round(w),
        height: Math.round(h),
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
      look: look,
      border: borderStyle,
      padding: padding,
      radius: radius,
      opacity: opacityPct,
      strokeOpacity: strokeOpacityPct,
      strokeWidth: strokeWidthPx,
      barWidth: Math.round(Number(window.contentItem.width) || 0),
      clusters: clusters,
      slots: slotRects
    }
    HuddleState.report(screenName, payload)
    drawList = HuddleDraw.build(payload, window.contentItem.width, window.contentItem.height, span, edgeVertical)
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
  onSettingsChanged: injectPanel()

  Timer {
    interval: 50
    running: true
    repeat: true
    onTriggered: root.measureHuddle()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    // bump: stroke width 0–5px, None is 0
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
