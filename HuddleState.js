.pragma library

function keyOf(payload, winW, winH, span, edgeVertical) {
  if (!payload) return ""
  // Keep the exact geometry inputs passed to HuddleDraw.build in the key.
  var s = [payload.look, payload.border, payload.padding, payload.radius, payload.opacity, payload.strokeOpacity, payload.strokeWidth, winW, winH, span, edgeVertical].join(",")
  var clusters = payload.clusters || []
  var slots = payload.slots || []
  for (var i = 0; i < clusters.length; i++) {
    var c = clusters[i]
    s += ";c" + [c.x, c.y, c.width, c.height].join(",")
  }
  for (var j = 0; j < slots.length; j++) {
    var t = slots[j]
    s += ";s" + [t.x, t.y, t.width, t.height, t.region].join(",")
  }
  return s
}
