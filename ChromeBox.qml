import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Item {
  id: box

  property string edge: "none"
  property bool glow: false
  property bool pointed: false
  property bool vertical: false
  property real roundness: 100
  property real fillAlpha: 0.62
  property real strokeAlpha: 1
  property int px: 1
  readonly property int strokePx: Math.max(0, Math.min(5, px))
  readonly property color fill: {
    var c = Color.bar.background
    if (!c || c.a < 0.18) c = Color.background
    return Util.alpha(c, fillAlpha)
  }
  readonly property color stroke: Util.alpha(Color.pick("hyprland.active-border", Color.accent), strokeAlpha)
  readonly property real tip: Math.min(vertical ? width / 2 : height / 2, Math.min(width, height) / 2)
  readonly property real rad: {
    var t = Number(roundness)
    if (!isFinite(t)) t = 100
    t = Math.max(0, Math.min(100, t))
    return (t / 100) * Math.min(width, height) / 2
  }

  Repeater {
    model: box.glow ? 3 : 0
    Rectangle {
      required property int index
      z: -1
      anchors.fill: parent
      anchors.leftMargin: -(index + 1) * 5
      anchors.rightMargin: -(index + 1) * 5
      anchors.topMargin: -Math.min(2, index + 1)
      anchors.bottomMargin: -Math.min(2, index + 1)
      radius: box.rad + (index + 1) * 4
      color: Qt.rgba(box.fill.r, box.fill.g, box.fill.b, 0.16 / (index + 1))
      visible: !box.pointed
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: !box.pointed
    radius: box.rad
    color: box.fill
    clip: true
    border.width: box.edge === "all" ? box.strokePx : 0
    border.color: box.stroke
    antialiasing: true

    Rectangle {
      visible: box.strokePx > 0 && (box.edge === "top" || box.edge === "horiz")
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: box.strokePx
      color: box.stroke
    }
    Rectangle {
      visible: box.strokePx > 0 && (box.edge === "bottom" || box.edge === "horiz")
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: box.strokePx
      color: box.stroke
    }
    Rectangle {
      visible: box.strokePx > 0 && box.edge === "sides"
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: box.strokePx
      color: box.stroke
    }
    Rectangle {
      visible: box.strokePx > 0 && box.edge === "sides"
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: box.strokePx
      color: box.stroke
    }
  }

  Shape {
    anchors.fill: parent
    visible: box.pointed
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true
    ShapePath {
      fillColor: box.fill
      strokeColor: box.strokePx > 0 ? box.stroke : "transparent"
      strokeWidth: box.strokePx
      capStyle: ShapePath.FlatCap
      joinStyle: ShapePath.MiterJoin
      startX: box.vertical ? 0 : box.tip
      startY: box.vertical ? box.tip : 0
      PathLine {
        x: box.vertical ? box.width : box.width - box.tip
        y: box.vertical ? box.tip : 0
      }
      PathLine {
        x: box.vertical ? box.width / 2 : box.width
        y: box.vertical ? 0 : box.height / 2
      }
      PathLine {
        x: box.vertical ? box.width : box.width - box.tip
        y: box.vertical ? box.height - box.tip : box.height
      }
      PathLine {
        x: box.vertical ? 0 : box.tip
        y: box.vertical ? box.height - box.tip : box.height
      }
      PathLine {
        x: box.vertical ? box.width / 2 : 0
        y: box.vertical ? box.height : box.height / 2
      }
      PathLine {
        x: box.vertical ? 0 : box.tip
        y: box.vertical ? box.tip : 0
      }
    }
  }
}
