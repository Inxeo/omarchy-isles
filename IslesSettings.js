.pragma library

var defaults = {chrome: true, look: "glow", border: "bottom", opacity: 66, strokeOpacity: 58, strokeWidth: 0, padding: 1, radius: 100}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function numeric(value) {
  if (typeof value !== "number" && typeof value !== "string") return NaN
  if (typeof value === "string" && value.trim() === "") return NaN
  var n = Number(value)
  return isFinite(n) ? n : NaN
}

function clampInt(n, min, max, fallback) {
  n = numeric(n)
  if (!isFinite(n)) return fallback
  return Math.max(min, Math.min(max, Math.round(n)))
}

function lookOf(raw) {
  var l = String(raw || defaults.look)
  if (l === "cluster" || l === "pills" || l === "rail" || l === "power" || l === "brackets" || l === "glow")
    return l
  return defaults.look
}

function borderOf(raw) {
  if (raw === undefined || raw === null) return defaults.border
  if (raw === true || raw === "true" || raw === "all") return "all"
  if (raw === "bottom") return "bottom"
  if (raw === "top") return "top"
  if (raw === "horiz") return "horiz"
  if (raw === "sides") return "sides"
  if (raw === "ends") return "ends"
  return "all"
}

function strokeWidthOf(settings) {
  return clampInt(settings && settings.strokeWidth, 0, 5, defaults.strokeWidth)
}

function fromSettings(settings) {
  var s = isObject(settings) ? settings : {}
  var look = lookOf(s.look)
  var border = borderOf(s.border)
  var strokeWidth = strokeWidthOf(s)
  return {
    chrome: s.chrome !== false,
    look: look,
    border: border,
    opacity: clampInt(s.opacity, 0, 100, defaults.opacity),
    strokeOpacity: clampInt(s.strokeOpacity, 0, 100, defaults.strokeOpacity),
    padding: clampInt(s.padding, 0, 20, defaults.padding),
    radius: clampInt(s.radius, 0, 100, defaults.radius),
    strokeWidth: strokeWidth,
    lookLocksRadius: look === "power" || look === "brackets" || border === "ends",
    lookLocksBorder: look === "power" || look === "brackets",
    hasDecoration: strokeWidth > 0
  }
}
