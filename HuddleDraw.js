.pragma library

function build(payload, winW, winH, span, edgeVertical) {
  var out = []
  if (!payload) return out
  var look = String(payload.look || "cluster")
  var pad = Number(payload.padding) || 0
  var inset = 2
  var border = payload.border
  var radius = payload.radius
  var fillAlpha = Math.max(0, Math.min(1, (Number(payload.opacity) || 0) / 100))
  var strokeOpacity = Number(payload.strokeOpacity)
  if (!isFinite(strokeOpacity)) strokeOpacity = 100
  var strokeAlpha = Math.max(0, Math.min(1, strokeOpacity / 100))
  var thick = Math.max(0, span - inset * 2)

  function boxItem(kind, x, y, w, h, extra) {
    if (![x, y, w, h].every(function(n) { return isFinite(n) })) return
    var it = {
      kind: kind,
      // Keep the shape's original bounds. The bar-surface clip cuts off the
      // overflow (including strokes/glow) without shifting or shrinking it.
      x: x,
      y: y,
      width: Math.max(0, w),
      height: Math.max(0, h),
      border: border,
      radius: radius,
      fillAlpha: fillAlpha,
      strokeAlpha: strokeAlpha,
      strokeWidth: (function() {
        var sw = Number(payload.strokeWidth)
        if (!isFinite(sw) || sw < 0) sw = 1
        return Math.max(0, Math.min(5, sw))
      })(),
      glow: look === "glow",
      pointed: kind === "box" && String(border) === "ends",
      first: false
    }
    if (extra) {
      for (var k in extra) it[k] = extra[k]
    }
    if (it.width > 0 && it.height > 0) out.push(it)
  }

  function place(kind, rawX, rawY, rawW, rawH, mode, extra) {
    var x, y, w, h
    if (edgeVertical) {
      x = inset
      w = thick
      if (mode === "gap") {
        y = Number(rawY) + pad / 2
        h = Number(rawH) - pad
      } else {
        y = Number(rawY) - pad
        h = Number(rawH) + pad * 2
      }
    } else {
      y = inset
      h = thick
      if (mode === "gap") {
        x = Number(rawX) + pad / 2
        w = Number(rawW) - pad
      } else {
        x = Number(rawX) - pad
        w = Number(rawW) + pad * 2
      }
    }
    boxItem(kind, x, y, w, h, extra)
  }

  var clusters = payload.clusters || []
  var slots = payload.slots || []

  if (look === "rail") {
    if (edgeVertical) boxItem("box", inset, 0, thick, winH)
    else boxItem("box", 0, inset, winW, thick)
    return out
  }

  if (look === "pills") {
    for (var p = 0; p < slots.length; p++) {
      var s = slots[p]
      place("box", s.x, s.y, s.width, s.height, "gap")
    }
    return out
  }

  if (look === "power") {
    var groups = { left: [], center: [], right: [] }
    for (var i = 0; i < slots.length; i++) {
      var sl = slots[i]
      var rg = String(sl.region || "center")
      if (!groups[rg]) groups[rg] = []
      groups[rg].push(sl)
    }
    var order = ["left", "center", "right"]
    for (var g = 0; g < order.length; g++) {
      var list = groups[order[g]] || []
      list.sort(function(a, b) {
        return edgeVertical ? (Number(a.y) - Number(b.y)) : (Number(a.x) - Number(b.x))
      })
      for (var n = 0; n < list.length; n++) {
        var seg = list[n]
        var tip = thick / 2
        if (edgeVertical) {
          var sy = Number(seg.y) - pad - (n > 0 ? tip : 0)
          var sh = Number(seg.height) + pad * 2 + tip + (n > 0 ? tip : 0)
          boxItem("power", inset, sy, thick, sh, { first: n === 0, pointed: true })
        } else {
          var sx = Number(seg.x) - pad - (n > 0 ? tip : 0)
          var sw = Number(seg.width) + pad * 2 + tip + (n > 0 ? tip : 0)
          boxItem("power", sx, inset, sw, thick, { first: n === 0, pointed: true })
        }
      }
    }
    return out
  }

  if (look === "brackets") {
    for (var b = 0; b < clusters.length; b++) {
      var c = clusters[b]
      place("bracket", c.x, c.y, c.width, c.height, "pad")
    }
    return out
  }

  for (var k = 0; k < clusters.length; k++) {
    var cl = clusters[k]
    place("box", cl.x, cl.y, cl.width, cl.height, "pad", {
      glow: look === "glow",
      pointed: String(border) === "ends"
    })
  }
  return out
}
