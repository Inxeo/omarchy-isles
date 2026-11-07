.pragma library

// Contrast against an opaque bar foreground. Test the worst possible wallpaper
// endpoint so no wallpaper sampling or host mutation is needed.
function linear(c) {
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}
function luminance(r, g, b) {
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
}
function ratio(a, b) {
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
}
function plan(r, g, b) {
  if (![r, g, b].every(function(c) { return typeof c === "number" && isFinite(c) && c >= 0 && c <= 1 }))
    return { light: false, opacity: 1 }
  var ink = luminance(r, g, b)
  var light = ratio(ink, 1) > ratio(ink, 0)
  var low = 0, high = 1
  for (var i = 0; i < 24; i++) {
    var alpha = (low + high) / 2
    var worst = light ? alpha : 1 - alpha
    var background = linear(worst)
    var rightSide = light ? background >= ink : background <= ink
    if (rightSide && ratio(ink, background) >= 4.5) high = alpha
    else low = alpha
  }
  // Contrast alone can leave distracting wallpaper detail behind small glyphs.
  // Keep light islands nearly opaque, and dark islands substantially opaque.
  // The calculated requirement can still raise either floor toward full opacity.
  var minimumOpacity = light ? 0.92 : 0.85
  return { light: light, opacity: Math.max(minimumOpacity, Math.min(1, high + 0.01)) }
}
