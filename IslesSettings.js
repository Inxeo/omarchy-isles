.pragma library

function clampInt(n, min, max, fallback) {
  n = Number(n)
  if (!isFinite(n)) return fallback
  return Math.max(min, Math.min(max, Math.round(n)))
}

function lookOf(raw) {
  var l = String(raw || "glow")
  if (l === "cluster" || l === "pills" || l === "rail" || l === "power" || l === "brackets" || l === "glow")
    return l
  return "glow"
}

function borderOf(raw) {
  if (raw === undefined) return "bottom"
  if (raw === true || raw === "true" || raw === "all") return "all"
  if (raw === "bottom") return "bottom"
  if (raw === "top") return "top"
  if (raw === "horiz") return "horiz"
  if (raw === "sides") return "sides"
  if (raw === "ends") return "ends"
  return "all"
}

function strokeWidthOf(settings) {
  var n = Number(settings && settings.strokeWidth)
  if (isFinite(n) && n >= 0) return clampInt(n, 0, 5, 1)
  var b = settings ? settings.border : undefined
  if (b === false || b === "false" || b === "none") return 0
  return 0
}

function fromSettings(settings) {
  var s = settings && typeof settings === "object" ? settings : {}
  var look = lookOf(s.look)
  var border = borderOf(s.border)
  var strokeWidth = strokeWidthOf(s)
  return {
    chrome: s.chrome !== false,
    look: look,
    border: border,
    opacity: clampInt(s.opacity, 0, 100, 66),
    strokeOpacity: clampInt(s.strokeOpacity, 0, 100, 58),
    padding: clampInt(s.padding, 0, 20, 1),
    radius: clampInt(s.radius, 0, 100, 100),
    strokeWidth: strokeWidth,
    lookLocksRadius: look === "power" || look === "brackets" || border === "ends",
    lookLocksBorder: look === "power" || look === "brackets",
    hasDecoration: strokeWidth > 0
  }
}
