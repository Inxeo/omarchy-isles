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
    { name: "Glowy", settings: snapshot(Settings.defaults) },
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

// Display only supported records, but never discard unreadable records on save.
function validRecord(p) {
  if (!Settings.isObject(p) || !nameOf(p.name) || !Settings.isObject(p.settings)) return false
  if (p.version !== undefined && p.version !== 1) return false
  var cfg = p.settings
  if (["cluster", "pills", "rail", "power", "brackets", "glow"].indexOf(cfg.look) < 0) return false
  if (["all", "top", "bottom", "horiz", "sides", "ends"].indexOf(cfg.border) < 0) return false
  var limits = {opacity: 100, strokeOpacity: 100, strokeWidth: 5, padding: 20, radius: 100}
  return Object.keys(limits).every(function(k) {
    var n = Settings.numeric(cfg[k])
    return isFinite(n) && n >= 0 && n <= limits[k] && Math.floor(n) === n
  })
}

function saved(raw) {
  if (!Array.isArray(raw)) return []
  var out = []
  var names = builtins().map(function(p) { return p.name.toLowerCase() })
  for (var i = 0; i < raw.length; i++) {
    var p = raw[i]
    if (!validRecord(p)) continue
    var name = nameOf(p.name)
    if (names.indexOf(name.toLowerCase()) !== -1) continue
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
  if (raw !== undefined && !Array.isArray(raw))
    return { error: "Saved preset data is not supported. It has been left unchanged." }
  var list = raw === undefined ? [] : JSON.parse(JSON.stringify(raw))
  var indices = []
  for (var i = 0; i < list.length; i++) {
    if (Settings.isObject(list[i]) && nameOf(list[i].name).toLowerCase() === name.toLowerCase()) indices.push(i)
  }
  if (indices.length > 1 || (indices.length === 1 && !validRecord(list[indices[0]])))
    return { error: "That name belongs to unsupported or duplicate preset data. Choose another name." }
  var preset = { name: name, version: 1, settings: snapshot(settings) }
  if (!indices.length) list.push(preset)
  else {
    // Preserve extension fields from other versions when updating known fields.
    var previous = list[indices[0]]
    for (var k in preset.settings) previous.settings[k] = preset.settings[k]
    previous.name = name
    previous.version = 1
  }
  return { presets: list }
}

function remove(raw, name) {
  name = nameOf(name)
  if (builtins().some(function(p) { return p.name.toLowerCase() === name.toLowerCase() }))
    return { error: "Built-in presets cannot be deleted." }
  if (!Array.isArray(raw)) return { error: "Saved preset data is not supported. Nothing was deleted." }
  var indices = []
  for (var i = 0; i < raw.length; i++) {
    if (Settings.isObject(raw[i]) && nameOf(raw[i].name).toLowerCase() === name.toLowerCase()) indices.push(i)
  }
  if (indices.length !== 1 || !validRecord(raw[indices[0]]))
    return { error: "That preset could not be identified safely. Nothing was deleted." }
  var list = JSON.parse(JSON.stringify(raw))
  list.splice(indices[0], 1)
  return { presets: list }
}
