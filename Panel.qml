pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "IslesSettings.js" as IslesSettings
import "Presets.js" as Presets
import "SettingsStore.js" as Store

Panel {
  id: root
  moduleName: "io.github.inxeo.isles"
  ipcTarget: "isles"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color errorColor: "#a55555"
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
  readonly property var presetOptions: presets.map(function(p, i) {
    return { value: String(i), label: p.name }
  })
  readonly property int contrastFloorPct: {
    if (!cfg.autoContrast || !hostWidget || !hostWidget.contrastPlan) return 0
    var n = Math.round(Number(hostWidget.contrastPlan.opacity) * 100)
    return isFinite(n) ? n : 0
  }
  readonly property int shownOpacityPct: Math.max(opacityPct, contrastFloorPct)
  readonly property bool opacityBoosted: cfg.autoContrast && shownOpacityPct > opacityPct
  readonly property bool saving: writer.busy
  property bool customizeOpen: true
  property string statusMessage: ""
  property bool lastFailed: false
  property var lastChanges: null
  property string lastSuccessMessage: ""
  property var undoSnapshot: null
  property string confirmKind: ""
  property string confirmName: ""

  function setLive(key, value) {
    if (hostWidget && hostWidget.setLiveOverride) hostWidget.setLiveOverride(key, value)
  }

  function writeSettings(changes, message, keepUndo) {
    if (saving) return
    if (!keepUndo) undoSnapshot = null
    statusMessage = ""
    lastFailed = false
    lastChanges = Store.clone(changes)
    lastSuccessMessage = message || ""
    writer.write(changes, message)
  }

  function persist(key, value) {
    setLive(key, value)
    var changes = {}
    changes[key] = value
    writeSettings(changes, "")
  }

  function rememberUndo() {
    undoSnapshot = {
      values: Presets.snapshot(settings),
      presetName: settings && settings.presetName ? settings.presetName : ""
    }
  }

  function applyPreset(value) {
    if (saving || value === "custom" || value === "") return
    var preset = presets[Number(value)]
    if (!preset) return
    rememberUndo()
    var changes = Presets.snapshot(preset.settings)
    changes.presetName = preset.name
    writeSettings(changes, "Applied " + preset.name + ".", true)
  }

  function undo() {
    if (!undoSnapshot || saving) return
    var snap = undoSnapshot
    undoSnapshot = null
    var changes = Presets.snapshot(snap.values)
    changes.presetName = snap.presetName
    writeSettings(changes, "Reverted.")
  }

  function retrySave() {
    if (saving || !lastChanges) return
    writeSettings(lastChanges, lastSuccessMessage)
  }

  function requestSave() {
    if (saving) return
    var name = Presets.nameOf(presetName.text)
    if (!name) return
    var updating = savedPresets.some(function(p) {
      return p.name.toLowerCase() === name.toLowerCase()
    })
    if (updating) {
      confirmKind = "update"
      confirmName = name
      confirm.opened = true
      return
    }
    savePreset(name)
  }

  function requestDelete() {
    if (saving || !selectedPersonalPreset) return
    confirmKind = "delete"
    confirmName = selectedPersonalPreset.name
    confirm.opened = true
  }

  function savePreset(name) {
    if (saving) return
    if (name === undefined) name = presetName.text
    var result = Presets.save(settings ? settings.savedPresets : undefined, name, settings)
    if (result.error) { statusMessage = result.error; lastFailed = true; return }
    name = Presets.nameOf(name)
    writeSettings({ savedPresets: result.presets, presetName: name }, "Saved " + name + ".")
  }

  function deletePreset() {
    if (saving || !selectedPersonalPreset) return
    var name = selectedPersonalPreset.name
    var result = Presets.remove(settings ? settings.savedPresets : undefined, name)
    if (result.error) { statusMessage = result.error; lastFailed = true; return }
    writeSettings({ savedPresets: result.presets, presetName: "" }, "Deleted " + name + ".")
  }

  function radiusLabel(n) {
    n = Math.round(Number(n) || 0)
    if (n <= 0) return "square"
    if (n >= 100) return "pill"
    return n + "%"
  }

  function opacityLabel(saved, shown) {
    if (cfg.autoContrast && shown > saved) return saved + "% saved · " + shown + "% shown"
    return saved + "%"
  }

  SettingsWriter {
    id: writer
    shellApi: root.bar ? root.bar.shell : null
    currentSettings: root.settings
    onCompleted: function(success, message) {
      root.lastFailed = !success
      root.statusMessage = message
      if (success) {
        if (root.hostWidget && root.hostWidget.clearLiveOverride)
          root.hostWidget.clearLiveOverride(Object.keys(root.lastChanges || {}))
        if (root.undoSnapshot) successFade.stop()
        else successFade.restart()
      } else {
        successFade.stop()
      }
    }
  }

  Timer {
    id: successFade
    interval: 3500
    onTriggered: {
      if (!root.lastFailed && !root.undoSnapshot) root.statusMessage = ""
    }
  }

  component FieldLabel: Text {
    property string valueText: ""
    color: root.fg
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
    opacity: 0.7
    text: valueText === "" ? "" : valueText
    wrapMode: Text.WordWrap
  }

  component Hint: Text {
    property string valueText: ""
    Layout.fillWidth: true
    text: valueText
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    color: root.fg
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.caption
    opacity: 0.7
    visible: valueText !== ""
  }

  component ChoiceFlow: Flow {
    id: flow
    property var options: []
    property string value: ""
    signal picked(string value)
    spacing: Style.space(6)
    Repeater {
      model: flow.options
      Button {
        required property var modelData
        text: modelData.label
        tooltipText: modelData.tooltip || ""
        selected: modelData.value === flow.value
        bordered: true
        foreground: root.fg
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        fontSize: Style.font.caption
        onClicked: flow.picked(modelData.value)
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    contentWidth: Style.space(300)
    contentHeight: fittedContentHeight(column.implicitHeight + Style.space(12), Style.space(560))
    padding: Style.space(18)

    Flickable {
      id: flick
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height

      ColumnLayout {
        id: column
        width: parent.width
        spacing: Style.space(12)

        Toggle {
          Layout.fillWidth: true
          label: "Show islands"
          description: "Paint islands behind the bar widgets."
          checked: root.chrome
          foreground: root.fg
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.persist("chrome", !root.chrome)
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.fg }

        PanelSectionHeader {
          Layout.fillWidth: true
          text: "Preset"
          foreground: root.fg
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
        Hint { valueText: "Presets save the look. Show islands and Auto contrast stay as they are." }

        Hint {
          visible: root.selectedPreset === "custom"
          valueText: "Custom — this look is not a saved preset."
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)
          Dropdown {
            id: presetDropdown
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            showLabel: false
            options: root.presetOptions
            foreground: root.fg
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            onChanged: function(v) { if (v !== root.selectedPreset) root.applyPreset(v) }
            Binding { target: presetDropdown; property: "value"; value: root.selectedPreset === "custom" ? "" : root.selectedPreset }
          }
          Button {
            visible: root.selectedPersonalPreset !== null
            text: "Delete"
            tooltipText: root.selectedPersonalPreset ? "Delete " + root.selectedPersonalPreset.name : ""
            bordered: true
            focusable: true
            foreground: root.fg
            onClicked: root.requestDelete()
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
            onAccepted: root.requestSave()
          }
          Button {
            text: root.savedPresets.some(function(p) {
              return p.name.toLowerCase() === Presets.nameOf(presetName.text).toLowerCase()
            }) ? "Update" : "Save"
            bordered: true
            focusable: true
            foreground: root.fg
            enabled: Presets.nameOf(presetName.text) !== ""
            onClicked: root.requestSave()
          }
        }

        Button {
          visible: root.selectedPreset !== "0"
          text: "Reset to Glowy"
          tooltipText: "Restore the default Glowy look. Your saved presets are kept."
          bordered: true
          focusable: true
          foreground: root.fg
          onClicked: root.applyPreset("0")
        }

        RowLayout {
          Layout.fillWidth: true
          visible: root.saving || root.statusMessage !== "" || root.undoSnapshot !== null
          spacing: Style.space(6)

          Text {
            Layout.fillWidth: true
            text: root.saving ? "Saving…" : root.statusMessage
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.lastFailed ? root.errorColor : root.fg
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          Button {
            visible: root.undoSnapshot !== null && !root.lastFailed && !root.saving
            text: "Undo"
            tooltipText: "Restore the previous look"
            bordered: true
            foreground: root.fg
            onClicked: root.undo()
          }
          Button {
            visible: root.lastFailed && root.lastChanges !== null && !root.saving
            text: "Retry"
            bordered: true
            foreground: root.fg
            onClicked: root.retrySave()
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.fg }

        RowLayout {
          Layout.fillWidth: true
          PanelSectionHeader {
            Layout.fillWidth: true
            text: "Customize"
            foreground: root.fg
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }
          Button {
            text: root.customizeOpen ? "Hide" : "Show"
            bordered: true
            foreground: root.fg
            onClicked: root.customizeOpen = !root.customizeOpen
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(12)
          visible: root.customizeOpen

          FieldLabel { valueText: "Look" }
          ChoiceFlow {
            Layout.fillWidth: true
            value: root.look
            options: [
              { value: "cluster", label: "Cluster", tooltip: "One island per bar section" },
              { value: "pills", label: "Pills", tooltip: "One island per widget" },
              { value: "rail", label: "Rail", tooltip: "A strip along the whole bar" },
              { value: "power", label: "Power", tooltip: "Chevron segments" },
              { value: "brackets", label: "Brackets", tooltip: "Corner marks around each section" },
              { value: "glow", label: "Glow", tooltip: "Softly glowing clusters" }
            ]
            onPicked: function(v) { root.persist("look", v) }
          }
          Hint {
            valueText: root.look === "cluster" ? "One island per bar section."
              : root.look === "pills" ? "One island per widget."
              : root.look === "rail" ? "A strip along the whole bar."
              : root.look === "power" ? "Chevron segments."
              : root.look === "brackets" ? "Corner marks around each section."
              : "Softly glowing clusters."
          }

          FieldLabel { valueText: "Border Style"; visible: !root.lookLocksBorder }
          ChoiceFlow {
            Layout.fillWidth: true
            visible: !root.lookLocksBorder
            value: root.borderStyle
            options: [
              { value: "all", label: "All", tooltip: "Outline every side" },
              { value: "ends", label: "Pointed", tooltip: "Pointed ends" },
              { value: "top", label: "Top", tooltip: "Top edge only" },
              { value: "bottom", label: "Bottom", tooltip: "Bottom edge only" },
              { value: "horiz", label: "Top+bot", tooltip: "Top and bottom" },
              { value: "sides", label: "Sides", tooltip: "Left and right" }
            ]
            onPicked: function(v) { root.persist("border", v) }
          }
          Hint { valueText: root.lookLocksBorder ? "Power and Brackets draw their own outline." : "" }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            RowLayout {
              Layout.fillWidth: true
              FieldLabel { valueText: "Padding"; Layout.fillWidth: true }
              FieldLabel { valueText: (padSlider.dragging ? Math.round(padSlider.liveValue) : root.padding) + "px" }
            }
            PanelSlider {
              id: padSlider
              Layout.fillWidth: true
              bar: root.bar
              minimum: 0
              maximum: 20
              step: 1
              integer: true
              value: root.padding
              onMoved: function(v) { root.setLive("padding", Math.round(v)) }
              onReleased: function(v) { root.persist("padding", Math.round(v)) }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            visible: !root.lookLocksRadius
            RowLayout {
              Layout.fillWidth: true
              FieldLabel { valueText: "Corner Radius"; Layout.fillWidth: true }
              FieldLabel { valueText: root.radiusLabel(radiusSlider.dragging ? radiusSlider.liveValue : root.radius) }
            }
            PanelSlider {
              id: radiusSlider
              Layout.fillWidth: true
              bar: root.bar
              minimum: 0
              maximum: 100
              step: 1
              integer: true
              value: root.radius
              onMoved: function(v) { root.setLive("radius", Math.round(v)) }
              onReleased: function(v) { root.persist("radius", Math.round(v)) }
            }
          }
          Hint { valueText: root.lookLocksRadius ? "Corner radius is not used with Power, Brackets, or Pointed." : "0 square, 100 pill." }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            RowLayout {
              Layout.fillWidth: true
              FieldLabel { valueText: "Background Opacity"; Layout.fillWidth: true }
              FieldLabel {
                valueText: root.opacityLabel(
                  opacitySlider.dragging ? Math.round(opacitySlider.liveValue) : root.opacityPct,
                  Math.max(opacitySlider.dragging ? Math.round(opacitySlider.liveValue) : root.opacityPct, root.contrastFloorPct)
                )
              }
            }
            PanelSlider {
              id: opacitySlider
              Layout.fillWidth: true
              bar: root.bar
              minimum: 0
              maximum: 100
              step: 1
              integer: true
              value: root.opacityPct
              onMoved: function(v) { root.setLive("opacity", Math.round(v)) }
              onReleased: function(v) { root.persist("opacity", Math.round(v)) }
            }
            Hint { valueText: root.opacityBoosted || (root.cfg.autoContrast && opacitySlider.dragging) ? "Auto contrast raises fill for contrast. The slider still stores your saved value." : "" }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            RowLayout {
              Layout.fillWidth: true
              FieldLabel { valueText: "Border Width"; Layout.fillWidth: true }
              FieldLabel { valueText: (widthSlider.dragging ? Math.round(widthSlider.liveValue) : root.strokeWidthPx) + "px" }
            }
            PanelSlider {
              id: widthSlider
              Layout.fillWidth: true
              bar: root.bar
              minimum: 0
              maximum: 5
              step: 1
              integer: true
              value: root.strokeWidthPx
              onMoved: function(v) { root.setLive("strokeWidth", Math.round(v)) }
              onReleased: function(v) { root.persist("strokeWidth", Math.round(v)) }
            }
            Hint { valueText: "0 hides the outline." }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            visible: root.hasDecoration
            RowLayout {
              Layout.fillWidth: true
              FieldLabel { valueText: "Border Opacity"; Layout.fillWidth: true }
              FieldLabel { valueText: (strokeSlider.dragging ? Math.round(strokeSlider.liveValue) : root.strokeOpacityPct) + "%" }
            }
            PanelSlider {
              id: strokeSlider
              Layout.fillWidth: true
              bar: root.bar
              minimum: 0
              maximum: 100
              step: 1
              integer: true
              value: root.strokeOpacityPct
              onMoved: function(v) { root.setLive("strokeOpacity", Math.round(v)) }
              onReleased: function(v) { root.persist("strokeOpacity", Math.round(v)) }
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.fg }

        Toggle {
          Layout.fillWidth: true
          label: "Auto contrast"
          description: "Light or dark fill against the bar text. May raise opacity; saved values stay put."
          checked: root.cfg.autoContrast
          foreground: root.fg
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          onClicked: root.persist("autoContrast", !root.cfg.autoContrast)
        }
      }
    }

    ConfirmDialog {
      id: confirm
      anchors.fill: parent
      z: 10
      message: root.confirmKind === "delete"
        ? ("Delete \"" + root.confirmName + "\"? The current look stays on the bar.")
        : ("Replace \"" + root.confirmName + "\" with the current look?")
      confirmText: root.confirmKind === "delete" ? "Delete" : "Replace"
      foreground: root.fg
      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
      onCanceled: confirm.opened = false
      onConfirmed: {
        confirm.opened = false
        if (root.confirmKind === "delete") root.deletePreset()
        else if (root.confirmKind === "update") root.savePreset(root.confirmName)
      }
      onOpenedChanged: if (confirm.opened) confirm.forceActiveFocus()
      Keys.onPressed: function(event) {
        if (confirm.handleKey(event)) event.accepted = true
      }
    }
  }
}
