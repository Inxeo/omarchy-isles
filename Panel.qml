pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "IslesSettings.js" as IslesSettings
import "Presets.js" as Presets

Panel {
  id: root
  moduleName: "io.github.inxeo.isles"
  ipcTarget: "isles"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property var cfg: IslesSettings.fromSettings(settings)
  readonly property bool chrome: cfg.chrome
  readonly property int opacityPct: cfg.opacity
  readonly property int strokeOpacityPct: cfg.strokeOpacity
  readonly property int padding: cfg.padding
  readonly property int radius: cfg.radius
  readonly property string look: cfg.look
  readonly property bool lookLocksRadius: cfg.lookLocksRadius
  readonly property bool lookLocksBorder: cfg.lookLocksBorder
  readonly property int strokeWidthPx: cfg.strokeWidth
  readonly property bool hasDecoration: cfg.hasDecoration
  readonly property string borderStyle: cfg.border

  readonly property var savedPresets: Presets.saved(settings ? settings.savedPresets : null)
  readonly property var presets: Presets.entries(savedPresets)
  readonly property string selectedPreset: Presets.matching(settings, presets)
  readonly property var selectedPersonalPreset: {
    var index = Number(selectedPreset)
    return isFinite(index) && index >= Presets.builtins().length ? presets[index] || null : null
  }
  readonly property var presetOptions: {
    var options = presets.map(function(p, i) {
      return { value: String(i), label: p.name }
    })
    if (selectedPreset === "custom") options.unshift({ value: "custom", label: "Custom" })
    return options
  }
  readonly property bool saving: writer.busy
  property string statusMessage: ""
  function writeSettings(changes, message) {
    if (saving) return
    statusMessage = ""
    writer.write(changes, message)
  }

  function persist(key, value) {
    var changes = {}
    changes[key] = value
    writeSettings(changes, "")
  }

  function applyPreset(value) {
    if (value === "custom") return
    var preset = presets[Number(value)]
    if (preset) {
      var changes = Presets.snapshot(preset.settings)
      changes.presetName = preset.name
      writeSettings(changes, "Applied " + preset.name + ".")
    }
  }

  function savePreset(name) {
    if (saving) return
    if (name === undefined) name = presetName.text
    var result = Presets.save(settings ? settings.savedPresets : undefined, name, settings)
    if (result.error) { statusMessage = result.error; return }
    name = Presets.nameOf(name)
    writeSettings({ savedPresets: result.presets, presetName: name }, "Saved " + name + ".")
  }

  function deletePreset() {
    if (saving || !selectedPersonalPreset) return
    var name = selectedPersonalPreset.name
    var result = Presets.remove(settings ? settings.savedPresets : undefined, name)
    if (result.error) { statusMessage = result.error; return }
    // Remove the saved entry, not the currently applied appearance.
    writeSettings({ savedPresets: result.presets, presetName: "" }, "Deleted " + name + ".")
  }

  SettingsWriter {
    id: writer
    shellApi: root.bar ? root.bar.shell : null
    currentSettings: root.settings
    onCompleted: function(success, message) { root.statusMessage = message }
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
    contentHeight: fittedContentHeight(column.implicitHeight + Style.space(12))
    padding: Style.space(18)

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: column
        width: parent.width
        spacing: Style.space(12)
        enabled: !root.saving

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

        FieldLabel { valueText: "Preset" }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)
          Dropdown {
            id: presetDropdown
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            options: root.presetOptions
            foreground: root.fg
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onChanged: function(v) { root.applyPreset(v) }
            Binding { target: presetDropdown; property: "value"; value: root.selectedPreset }
          }
          Button {
            visible: root.selectedPersonalPreset !== null
            text: "Delete"
            tooltipText: root.selectedPersonalPreset ? "Delete " + root.selectedPersonalPreset.name : ""
            bordered: true
            focusable: true
            foreground: root.fg
            onClicked: root.deletePreset()
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)
          TextField {
            id: presetName
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            placeholderText: "Name your preset"
            maximumLength: 40
            foreground: root.fg
            onAccepted: root.savePreset()
          }
          Button {
            text: root.savedPresets.some(function(p) {
              return p.name.toLowerCase() === Presets.nameOf(presetName.text).toLowerCase()
            }) ? "Update" : "Save"
            bordered: true
            focusable: true
            foreground: root.fg
            enabled: Presets.nameOf(presetName.text) !== ""
            onClicked: root.savePreset()
          }
        }

        Text {
          Layout.fillWidth: true
          visible: root.saving || root.statusMessage !== ""
          text: root.saving ? "Saving…" : root.statusMessage
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          color: root.fg
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
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
}
