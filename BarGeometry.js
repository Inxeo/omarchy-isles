.pragma library

// All assumptions about Omarchy's private scene layout live in this adapter.
// Retain a periodic discovery pass so replacing slots/layouts recovers itself.

// 4.5 strip sections in reading order. Tray lives in a drawer off the strip.
var paintedRegions = ["left", "centerBegin", "center", "centerEnd", "right"]

function isPaintedRegion(region) {
  return paintedRegions.indexOf(String(region || "")) >= 0
}

function paintedOrder() {
  var out = []
  for (var i = 0; i < paintedRegions.length; i++) out.push(paintedRegions[i])
  return out
}

function emptyBoxes() {
  var boxes = {}
  for (var i = 0; i < paintedRegions.length; i++) {
    boxes[paintedRegions[i]] = {
      minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity, found: false
    }
  }
  return boxes
}

function findSurfaceRoot(parent, surface, vertical) {
  if (!surface) return null
  var extent = Number(vertical ? surface.height : surface.width)
  if (!isFinite(extent) || extent <= 0) return null
  var best = null
  var visited = []
  try {
    for (var p = parent; p && visited.indexOf(p) < 0; p = p.parent) {
      visited.push(p)
      var along = Number(vertical ? p.height : p.width)
      if (isFinite(along) && along > extent * 0.9) best = p
    }
  } catch (e) { return null }
  return best
}

// Direct children of the 4.5 bar window: pick the strip (full span, bar
// thickness) rather than the full-screen contentItem. Callers must pass
// surface width/height/children from QML so the binding tracks those values.
function findStripChild(surface, children, surfaceW, surfaceH, vertical, barSize) {
  if (!surface) return null
  var longSurface = Number(vertical ? surfaceH : surfaceW)
  var wantThick = Number(barSize)
  if (!isFinite(longSurface) || longSurface <= 0) return null
  var best = null
  var bestScore = Infinity
  try {
    if (!children) return surface
    var n = children.length
    for (var i = 0; i < n; i++) {
      var p = children[i]
      if (!p || p.visible === false || p.enabled === false) continue
      var along = Number(vertical ? p.height : p.width)
      var across = Number(vertical ? p.width : p.height)
      if (!isFinite(along) || along <= longSurface * 0.9 || !isFinite(across) || across <= 0) continue
      var score = isFinite(wantThick) && wantThick > 0 ? Math.abs(across - wantThick) : across
      if (score < bestScore) {
        bestScore = score
        best = p
      }
    }
  } catch (e) { return surface }
  return best || surface
}

// Ancestor walk kept for tests and as a fallback when the strip is not a
// direct child of the window (the 4.0-era bar window was the strip).
function findPaintRoot(parent, surface, vertical, barSize) {
  if (!surface) return null
  var longSurface = Number(vertical ? surface.height : surface.width)
  var wantThick = Number(barSize)
  if (!isFinite(longSurface) || longSurface <= 0) return null
  var visited = []
  var best = null
  var bestScore = Infinity
  try {
    for (var p = parent; p && visited.indexOf(p) < 0; p = p.parent) {
      visited.push(p)
      var along = Number(vertical ? p.height : p.width)
      var across = Number(vertical ? p.width : p.height)
      if (isFinite(along) && along > longSurface * 0.9 && isFinite(across) && across > 0) {
        var score = across
        if (isFinite(wantThick) && wantThick > 0) score = Math.abs(across - wantThick)
        if (score < bestScore) {
          bestScore = score
          best = p
        }
      }
      if (p === surface) break
    }
  } catch (e) { return null }
  return best || surface
}

function isSlot(item) {
  try {
    if (!item || !isPaintedRegion(item.region)) return false
    if (item.dragSource === true || item.removalPending === true) return false
    return typeof item.moduleName === "string" && item.moduleName.length > 0
      && item.activeItem !== undefined && typeof item.mapToItem === "function"
      && isFinite(Number(item.width)) && isFinite(Number(item.height))
  } catch (e) { return false }
}

function slotsIn(item) {
  var slots = []
  function visit(node) {
    try {
      if (!node || node.visible === false || node.enabled === false) return
      if (isSlot(node)) { slots.push(node); return }
      var children = node.children
      if (!children) return
      for (var i = 0; i < children.length; i++) visit(children[i])
    } catch (e) { /* A slot can disappear during a layout/plugin reload. */ }
  }
  visit(item)
  return slots
}
