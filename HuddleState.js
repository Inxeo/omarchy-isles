.pragma library

var huddles = {}
var serial = 0

function report(screenName, payload) {
  var key = String(screenName || "")
  if (!key) return
  huddles[key] = payload && typeof payload === "object" ? payload : null
  serial++
}

function forScreen(screenName) {
  return huddles[String(screenName || "")] || null
}

function keyOf(payload) {
  if (!payload) return ""
  var s = [payload.look, payload.border, payload.padding, payload.radius, payload.opacity, payload.strokeOpacity, payload.strokeWidth, payload.barWidth].join(",")
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
