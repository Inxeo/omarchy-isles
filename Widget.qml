import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "HuddleState.js" as HuddleState
import "BarGeometry.js" as BarGeometry
import "HuddleDraw.js" as HuddleDraw
import "IslesSettings.js" as IslesSettings
import "AutoContrast.js" as AutoContrast

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
  property var liveOverride: ({})

  function copyOverride(src) {
    var next = {}
    if (!src) return next
    var keys = Object.keys(src)
    var i = 0
    while (i < keys.length) {
      next[keys[i]] = src[keys[i]]
      i += 1
    }
    return next
  }

  function setLiveOverride(key, value) {
    var next = copyOverride(liveOverride)
    if (value === undefined) delete next[key]
    else next[key] = value
    liveOverride = next
  }

  function clearLiveOverride(keys) {
    if (!keys || !keys.length) {
      liveOverride = ({})
      return
    }
    var cur = liveOverride
    if (!cur) {
      liveOverride = ({})
      return
    }
    var next = {}
    var keep = false
    var srcKeys = Object.keys(cur)
    var i = 0
    var k
    while (i < srcKeys.length) {
      k = srcKeys[i]
      i += 1
      if (keys.indexOf(k) >= 0) continue
      next[k] = cur[k]
      keep = true
    }
    liveOverride = keep ? next : ({})
  }

  readonly property var cfg: IslesSettings.merge(settings, liveOverride)
  readonly property bool chrome: cfg.chrome
  // barForeground is Omarchy's effective wallpaper-adaptive text colour.
  readonly property color contrastForeground: {
    var host = root.bar
    return host && host.barForeground !== undefined ? host.barForeground : Commons.Color.bar.text
  }
  readonly property var contrastPlan: cfg.autoContrast
    ? AutoContrast.plan(contrastForeground.r, contrastForeground.g, contrastForeground.b)
    : ({ light: false, opacity: 0 })
  readonly property color contrastBackground: !cfg.autoContrast ? "transparent"
    : contrastPlan.light ? "white" : "black"
  readonly property bool edgeVertical: !!(bar && bar.vertical)
  readonly property int span: {
    if (bar && Number(bar.barSize) > 0) return Number(bar.barSize)
    return edgeVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  }
  readonly property var windowSurface: {
    var w = root.QsWindow ? root.QsWindow.window : null
    return w && w.contentItem ? w.contentItem : null
  }
  readonly property var barLayer: chromeHost

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property int discoveryMisses: 0
  property bool discoveryWarning: false

  function discoverSlots() {
    var survey = root.windowSurface
    var slots = survey ? BarGeometry.slotsIn(survey) : []
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

  // 4.5 BarPanel is the whole screen. Place chrome on the edge that currently
  // holds this widget, using the public position when it is set and the
  // widget's mapped coordinates otherwise (mapToItem is a one-shot, so this
  // runs from the measure timer whenever the bar moves).
  function placeChrome() {
    var s = root.windowSurface
    var host = chromeHost
    if (!s || !host) return
    var sw = Number(s.width)
    var sh = Number(s.height)
    var thick = root.span
    if (!isFinite(sw) || !isFinite(sh) || sw <= 0 || sh <= 0 || thick <= 0) return
    var pos = ""
    var origin = null
    var onRight = false
    var onBottom = false
    try { if (root.bar && root.bar.position) pos = String(root.bar.position) } catch (e) {}
    try { origin = root.mapToItem(s, 0, 0) } catch (e) {}
    if (root.edgeVertical) {
      onRight = pos === "right" || (origin && origin.x > sw * 0.5)
      host.x = onRight ? Math.max(0, sw - thick) : 0
      host.y = 0
      host.width = thick
      host.height = sh
    } else {
      onBottom = pos === "bottom" || (origin && origin.y > sh * 0.5)
      host.x = 0
      host.y = onBottom ? Math.max(0, sh - thick) : 0
      host.width = sw
      host.height = thick
    }
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

    placeChrome()
    var layer = chromeHost
    if (!layer || layer.width <= 0 || layer.height <= 0) return

    var slots = discoverSlots()
    if (!slots.length) {
      root.drawList = []
      root.lastDrawKey = ""
      return
    }

    var boxes = BarGeometry.emptyBoxes()
    var order = BarGeometry.paintedOrder()
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
        origin = slot.mapToItem(layer, 0, 0)
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
    var key = HuddleState.keyOf(payload, layer.width, layer.height, span, edgeVertical)
    if (key === root.lastDrawKey) {
      return
    }
    root.lastDrawKey = key
    root.drawList = HuddleDraw.build(payload, layer.width, layer.height, span, edgeVertical)
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
  onLiveOverrideChanged: Qt.callLater(measureHuddle)

  Connections {
    target: root.barLayer
    function onWidthChanged() { Qt.callLater(root.measureHuddle) }
    function onHeightChanged() { Qt.callLater(root.measureHuddle) }
  }

  Connections {
    target: root.bar
    function onPositionChanged() {
      root.lastDrawKey = ""
      Qt.callLater(root.measureHuddle)
    }
    function onVerticalChanged() {
      root.lastDrawKey = ""
      Qt.callLater(root.measureHuddle)
    }
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
    tooltipText: root.opened ? "Close Isles" : "Island appearance"

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }

  // Paint on the bar strip, under the widgets. A separate Bottom layer
  // sat on top of left/right bars and made icons look washed out. On 4.5
  // the window is the whole screen; the strip is the edge that holds widgets.
  Item {
    id: chromeHost
    parent: root.windowSurface
    z: -1000
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
          return Math.max(isFinite(n) ? n : 0.62, root.contrastPlan.opacity)
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
            contrastBackground: root.contrastBackground
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
            contrastBackground: root.contrastBackground
            fillAlpha: piece.fillInk
            strokeAlpha: piece.strokeInk
            px: Number(piece.modelData.strokeWidth)
          }
        }

        Component {
          id: bracketRenderer
          BracketChrome {
            anchors.fill: parent
            contrastBackground: root.contrastBackground
            fillAlpha: piece.fillInk
            strokeAlpha: piece.strokeInk
            px: Number(piece.modelData.strokeWidth)
          }
        }
      }
    }
  }
}
