import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

// Powerline segment: points right on a horizontal bar, down on a vertical bar.
Shape {
  id: root
  property bool first: false
  property bool vertical: false
  property real fillAlpha: 0.62
  property real strokeAlpha: 1
  property int px: 1
  readonly property color fill: {
    var c = Color.bar.background
    if (!c || c.a < 0.18) c = Color.background
    return Util.alpha(c, fillAlpha)
  }
  readonly property color stroke: Util.alpha(Color.pick("hyprland.active-border", Color.accent), strokeAlpha)
  readonly property real tip: vertical
    ? Math.min(width / 2, height / 3)
    : Math.min(height / 2, width / 3)

  preferredRendererType: Shape.CurveRenderer
  antialiasing: true

  ShapePath {
    fillColor: root.fill
    strokeColor: root.px > 0 ? root.stroke : "transparent"
    strokeWidth: Math.max(0, Math.min(5, root.px))
    capStyle: ShapePath.FlatCap
    joinStyle: ShapePath.MiterJoin
    startX: {
      if (root.vertical) return 0
      return root.first ? 0 : root.tip
    }
    startY: {
      if (!root.vertical) return 0
      return root.first ? 0 : root.tip
    }
    PathLine {
      x: root.vertical ? root.width : root.width - root.tip
      y: root.vertical ? (root.first ? 0 : root.tip) : 0
    }
    PathLine {
      x: root.vertical ? root.width : root.width
      y: root.vertical ? root.height - root.tip : root.height / 2
    }
    PathLine {
      x: root.vertical ? root.width / 2 : root.width - root.tip
      y: root.vertical ? root.height : root.height
    }
    PathLine {
      x: root.vertical ? 0 : (root.first ? 0 : root.tip)
      y: root.vertical ? root.height - root.tip : root.height
    }
    PathLine {
      x: root.vertical ? 0 : 0
      y: root.vertical ? (root.first ? 0 : root.tip) : (root.first ? root.height : root.height / 2)
    }
    PathLine {
      x: root.vertical ? 0 : (root.first ? 0 : root.tip)
      y: root.vertical ? (root.first ? 0 : root.tip) : 0
    }
  }
}
