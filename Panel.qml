pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.inxeo.isles"
  ipcTarget: "isles"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property bool chrome: setting("chrome", true) !== false
  readonly property int opacityPct: Number(setting("opacity", 62))
  readonly property int strokeOpacityPct: {
    var n = Number(setting("strokeOpacity", 100))
    return isFinite(n) ? n : 100
  }
  readonly property int padding: Number(setting("padding", 8))
  readonly property int radius: Number(setting("radius", 100))
  readonly property string look: {
    var l = String(setting("look", "cluster") || "cluster")
    if (l === "pills" || l === "rail" || l === "power" || l === "brackets" || l === "glow")
      return l
    return "cluster"
  }
  readonly property bool lookLocksRadius: look === "power" || look === "brackets" || borderStyle === "ends"
  readonly property bool lookLocksBorder: look === "power" || look === "brackets"
  readonly property int strokeWidthPx: {
    var n = Number(setting("strokeWidth", -1))
    if (isFinite(n) && n >= 0) return Math.max(0, Math.min(5, Math.round(n)))
    var b = setting("border", "all")
    if (b === false || b === "false" || b === "none") return 0
    return 1
  }
  readonly property bool hasDecoration: strokeWidthPx > 0
  readonly property string borderStyle: {
    var b = setting("border", "all")
    if (b === true || b === "true" || b === "all") return "all"
    if (b === "bottom") return "bottom"
    if (b === "top") return "top"
    if (b === "horiz") return "horiz"
    if (b === "sides") return "sides"
    if (b === "ends") return "ends"
    return "all"
  }

  function persist(key, value) {
    var args = ["omarchy", "bar", "set", "io.github.inxeo.isles", key]
    if (typeof value === "boolean" || typeof value === "number") {
      args.push(JSON.stringify(value))
      args.push("--json")
    } else {
      args.push(String(value))
    }
    Quickshell.execDetached(args)
  }

  component Hairline: Rectangle {
    Layout.fillWidth: true
    implicitHeight: 1
    color: root.fg
    opacity: 0.12
  }

  component FieldLabel: Text {
    property string valueText: ""
    color: root.fg
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
    opacity: 0.7
    text: valueText === "" ? "" : valueText
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    contentWidth: Style.space(300)
    contentHeight: column.implicitHeight + padding * 2 + Style.space(12)
    padding: Style.space(18)

    ColumnLayout {
      id: column
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(12)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          text: "Isles"
          color: root.fg
          font.family: bar ? bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          Layout.fillWidth: true
        }

        ToggleSwitch {
          checked: root.chrome
          foreground: root.fg
          accent: Color.accent
          onToggled: root.persist("chrome", !root.chrome)
        }
      }

      Hairline {}

      FieldLabel { valueText: "Look" }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        ButtonGroup {
          Layout.fillWidth: true
          options: [
            { value: "cluster", label: "Cluster" },
            { value: "pills", label: "Pills" },
            { value: "rail", label: "Rail" }
          ]
          value: root.look
          foreground: root.fg
          accent: Color.accent
          fontFamily: bar ? bar.fontFamily : Style.font.family
          fontSize: Style.font.caption
          onChanged: function(v) { root.persist("look", v) }
        }

        ButtonGroup {
          Layout.fillWidth: true
          options: [
            { value: "power", label: "Power" },
            { value: "brackets", label: "Brackets" },
            { value: "glow", label: "Glow" }
          ]
          value: root.look
          foreground: root.fg
          accent: Color.accent
          fontFamily: bar ? bar.fontFamily : Style.font.family
          fontSize: Style.font.caption
          onChanged: function(v) { root.persist("look", v) }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        opacity: root.lookLocksBorder ? 0.4 : 1
        enabled: !root.lookLocksBorder

        FieldLabel { valueText: root.lookLocksBorder ? "Stroke  unused" : "Stroke" }

        ButtonGroup {
          Layout.fillWidth: true
          options: [
            { value: "all", label: "All" },
            { value: "ends", label: "Ends" }
          ]
          value: root.borderStyle
          foreground: root.fg
          accent: Color.accent
          fontFamily: bar ? bar.fontFamily : Style.font.family
          fontSize: Style.font.caption
          onChanged: function(v) { root.persist("border", v) }
        }

        ButtonGroup {
          Layout.fillWidth: true
          options: [
            { value: "top", label: "Top" },
            { value: "bottom", label: "Bottom" },
            { value: "horiz", label: "T+B" },
            { value: "sides", label: "Sides" }
          ]
          value: root.borderStyle
          foreground: root.fg
          accent: Color.accent
          fontFamily: bar ? bar.fontFamily : Style.font.family
          fontSize: Style.font.caption
          onChanged: function(v) { root.persist("border", v) }
        }
      }

      Hairline {}

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        RowLayout {
          Layout.fillWidth: true
          FieldLabel { valueText: "Fill"; Layout.fillWidth: true }
          FieldLabel { valueText: root.opacityPct + "%" }
        }
        PanelSlider {
          Layout.fillWidth: true
          bar: root.bar
          minimum: 0
          maximum: 100
          step: 1
          integer: true
          value: root.opacityPct
          onReleased: function(v) { root.persist("opacity", Math.round(v)) }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        RowLayout {
          Layout.fillWidth: true
          FieldLabel { valueText: "Width"; Layout.fillWidth: true }
          FieldLabel { valueText: root.strokeWidthPx + "px" }
        }
        PanelSlider {
          Layout.fillWidth: true
          bar: root.bar
          minimum: 0
          maximum: 5
          step: 1
          integer: true
          value: root.strokeWidthPx
          onReleased: function(v) { root.persist("strokeWidth", Math.round(v)) }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        opacity: root.hasDecoration ? 1 : 0.4
        enabled: root.hasDecoration

        RowLayout {
          Layout.fillWidth: true
          FieldLabel {
            Layout.fillWidth: true
            valueText: root.hasDecoration ? "Stroke" : "Stroke  unused"
          }
          FieldLabel { valueText: root.hasDecoration ? root.strokeOpacityPct + "%" : "" }
        }
        PanelSlider {
          Layout.fillWidth: true
          bar: root.bar
          minimum: 0
          maximum: 100
          step: 1
          integer: true
          value: root.strokeOpacityPct
          onReleased: function(v) { root.persist("strokeOpacity", Math.round(v)) }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        RowLayout {
          Layout.fillWidth: true
          FieldLabel { valueText: "Padding"; Layout.fillWidth: true }
          FieldLabel { valueText: root.padding + "px" }
        }
        PanelSlider {
          Layout.fillWidth: true
          bar: root.bar
          minimum: 0
          maximum: 20
          step: 1
          integer: true
          value: root.padding
          onReleased: function(v) { root.persist("padding", Math.round(v)) }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        opacity: root.lookLocksRadius ? 0.4 : 1
        enabled: !root.lookLocksRadius

        RowLayout {
          Layout.fillWidth: true
          FieldLabel {
            Layout.fillWidth: true
            valueText: root.lookLocksRadius ? "Radius  unused" : "Radius"
          }
          FieldLabel {
            valueText: root.lookLocksRadius ? "" : (root.radius <= 0 ? "square" : (root.radius >= 100 ? "pill" : root.radius + "%"))
          }
        }
        PanelSlider {
          Layout.fillWidth: true
          bar: root.bar
          minimum: 0
          maximum: 100
          step: 1
          integer: true
          value: root.radius
          onReleased: function(v) { root.persist("radius", Math.round(v)) }
        }
      }
    }
  }
}
