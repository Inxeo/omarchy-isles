.pragma library

function object(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function clone(value) { return JSON.parse(JSON.stringify(value)) }

function equal(a, b) {
  if (a === b) return true
  if (!a || !b || typeof a !== "object" || typeof b !== "object") return false
  if (Array.isArray(a) !== Array.isArray(b)) return false
  var ak = Object.keys(a), bk = Object.keys(b)
  return ak.length === bk.length && ak.every(function(k) {
    return Object.prototype.hasOwnProperty.call(b, k) && equal(a[k], b[k])
  })
}

function plan(current, changes) {
  var before = clone(object(current) ? current : {})
  var target = clone(before)
  var keys = Object.keys(changes).filter(function(k) { return !equal(before[k], changes[k]) })
  keys.forEach(function(k) { target[k] = clone(changes[k]) })
  return { before: before, target: target, keys: keys }
}

function matches(current, expected, keys) {
  return object(current) && keys.every(function(k) { return equal(current[k], expected[k]) })
}

function restore(current, transaction) {
  // Never undo a subsequent change from another panel/monitor.
  if (!matches(current, transaction.target, transaction.keys)) return null
  var restored = clone(current)
  transaction.keys.forEach(function(k) {
    if (Object.prototype.hasOwnProperty.call(transaction.before, k)) restored[k] = clone(transaction.before[k])
    else delete restored[k]
  })
  return restored
}

function entryFromText(text, id) {
  try {
    var config = JSON.parse(text)
    var layout = config.bar && config.bar.layout
    if (!object(layout)) return null
    var entries = []
    ;["left", "center", "right"].forEach(function(section) {
      if (Array.isArray(layout[section])) entries = entries.concat(layout[section])
    })
    var matches = entries.filter(function(e) { return object(e) && e.id === id })
    return matches.length === 1 ? matches[0] : null
  } catch (e) { return null }
}
