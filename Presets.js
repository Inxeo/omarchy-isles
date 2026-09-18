.pragma library
.import "IslesSettings.js" as Settings

var keys = ["look", "border", "opacity", "strokeOpacity", "strokeWidth", "padding", "radius"]

function snapshot(settings) {
  var cfg = Settings.fromSettings(settings)
  var out = {}
  for (var i = 0; i < keys.length; i++) out[keys[i]] = cfg[keys[i]]
  return out
}

function builtins() {
  return [
    { name: "Glowy", settings: { look: "glow", border: "bottom", opacity: 66, strokeOpacity: 58, strokeWidth: 0, padding: 1, radius: 100 } },
    { name: "Halo", settings: { look: "cluster", border: "all", opacity: 45, strokeOpacity: 80, strokeWidth: 1, padding: 10, radius: 100 } },
    { name: "Pebbles", settings: { look: "pills", border: "all", opacity: 65, strokeOpacity: 45, strokeWidth: 1, padding: 4, radius: 100 } },
    { name: "Underline", settings: { look: "rail", border: "bottom", opacity: 28, strokeOpacity: 85, strokeWidth: 1, padding: 0, radius: 0 } },
    { name: "Arrowhead", settings: { look: "power", border: "all", opacity: 65, strokeOpacity: 65, strokeWidth: 1, padding: 2, radius: 0 } },
    { name: "Blueprint", settings: { look: "brackets", border: "all", opacity: 20, strokeOpacity: 90, strokeWidth: 2, padding: 8, radius: 0 } }
  ]
}

function nameOf(value) {
  return typeof value === "string" ? value.trim().slice(0, 40) : ""
}

function saved(raw) {
  if (!Array.isArray(raw)) return []
  var out = []
  var names = builtins().map(function(p) { return p.name.toLowerCase() })
  for (var i = 0; i < raw.length; i++) {
    var p = raw[i]
    var name = p ? nameOf(p.name) : ""
    if (!name || names.indexOf(name.toLowerCase()) !== -1 || !p.settings || typeof p.settings !== "object") continue
    names.push(name.toLowerCase())
    out.push({ name: name, settings: snapshot(p.settings) })
  }
  return out
}

function entries(raw) {
  return builtins().concat(saved(raw))
}

function matching(settings, presets) {
  var current = snapshot(settings)
  var preferred = settings ? settings.presetName : ""
  var match = "custom"
  for (var i = 0; i < presets.length; i++) {
    var p = presets[i].settings
    if (keys.every(function(k) { return current[k] === p[k] })) {
      if (presets[i].name === preferred) return String(i)
      if (match === "custom") match = String(i)
    }
  }
  return match
}

function save(raw, name, settings) {
  name = nameOf(name)
  if (!name) return { error: "Enter a preset name." }
  if (builtins().some(function(p) { return p.name.toLowerCase() === name.toLowerCase() }))
    return { error: "Choose a name other than a built-in preset." }
  var list = saved(raw)
  var preset = { name: name, settings: snapshot(settings) }
  var index = list.findIndex(function(p) { return p.name.toLowerCase() === name.toLowerCase() })
  if (index < 0) list.push(preset)
  else list[index] = preset
  return { presets: list }
}
