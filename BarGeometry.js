.pragma library

// All assumptions about Omarchy's private scene layout live in this adapter.
// Retain a periodic discovery pass so replacing slots/layouts recovers itself.
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

function isSlot(item) {
  try {
    return item && ["left", "center", "right"].indexOf(item.region) >= 0
      && typeof item.moduleName === "string" && item.moduleName.length > 0
      && item.activeItem !== undefined && typeof item.mapToItem === "function"
      && isFinite(Number(item.width)) && isFinite(Number(item.height))
  } catch (e) { return false }
}

function slotsIn(item) {
  var slots = []
  function visit(node) {
    try {
      if (!node || node.visible === false) return
      if (isSlot(node)) { slots.push(node); return }
      var children = node.children
      if (!children) return
      for (var i = 0; i < children.length; i++) visit(children[i])
    } catch (e) { /* A slot can disappear during a layout/plugin reload. */ }
  }
  visit(item)
  return slots
}
