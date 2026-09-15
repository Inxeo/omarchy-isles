import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property real fillAlpha: 0
  property real strokeAlpha: 1
  readonly property color fill: {
    var c = Color.bar.background
    if (!c || c.a < 0.18) c = Color.background
    return Util.alpha(c, fillAlpha)
  }
  readonly property color stroke: Util.alpha(Color.pick("hyprland.active-border", Color.accent), strokeAlpha)
  property int px: 2
  property int arm: Math.max(6, Math.min(14, Math.round(Math.min(width, height) * 0.45)))
  property int thick: Math.max(0, Math.min(5, px))

  Rectangle {
    anchors.fill: parent
    color: root.fill
    visible: root.fillAlpha > 0.01
  }

  Rectangle { visible: root.thick > 0; width: root.arm; height: root.thick; color: root.stroke; anchors.left: parent.left; anchors.top: parent.top }
  Rectangle { visible: root.thick > 0; width: root.thick; height: root.arm; color: root.stroke; anchors.left: parent.left; anchors.top: parent.top }
  Rectangle { visible: root.thick > 0; width: root.arm; height: root.thick; color: root.stroke; anchors.right: parent.right; anchors.top: parent.top }
  Rectangle { visible: root.thick > 0; width: root.thick; height: root.arm; color: root.stroke; anchors.right: parent.right; anchors.top: parent.top }
  Rectangle { visible: root.thick > 0; width: root.arm; height: root.thick; color: root.stroke; anchors.left: parent.left; anchors.bottom: parent.bottom }
  Rectangle { visible: root.thick > 0; width: root.thick; height: root.arm; color: root.stroke; anchors.left: parent.left; anchors.bottom: parent.bottom }
  Rectangle { visible: root.thick > 0; width: root.arm; height: root.thick; color: root.stroke; anchors.right: parent.right; anchors.bottom: parent.bottom }
  Rectangle { visible: root.thick > 0; width: root.thick; height: root.arm; color: root.stroke; anchors.right: parent.right; anchors.bottom: parent.bottom }
}
