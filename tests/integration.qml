import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "Isles" as Isles
import "Isles/Presets.js" as Presets
import "Isles/SettingsStore.js" as Store

Scope {
  id: suite
  property string configPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
  property var live: ({})
  property int calls: 0
  property string mode: "ok"
  property int step: -1
  property var before: ({})
  property var cases: []
  property bool done: false
  property int panelStage: 0
  property var appearanceBeforeDelete: ({})
  property int renderIndex: 0
  property var renderCases: Presets.builtins().concat([
    {name: "Power (manual)", settings: {look:"power",border:"all",opacity:65,strokeOpacity:65,strokeWidth:1,padding:2,radius:0}}
  ])
  property var renderSettings: renderCases[0].settings

  function merged(base, extra) {
    var result = Store.clone(base)
    Object.keys(extra).forEach(function(k) { result[k] = extra[k] })
    return result
  }
  function check(condition, message) {
    if (!condition) { console.error("ISLES_FAIL: " + message); done = true; Qt.quit() }
    return condition
  }
  function writeDisk(value) {
    disk.setText(JSON.stringify({version:1,bar:{layout:{left:[merged(value,{id:"io.github.inxeo.isles"})],center:[],right:[]}}}))
  }
  function next() {
    if (done) return
    step++
    if (step === cases.length) {
      // Exercise the real panel's preset action and its writer integration.
      mode = "ok"; calls = 0
      panel.applyPreset("1")
      return
    }
    var test = cases[step]
    mode = test.mode || "ok"; calls = 0
    before = Store.clone(live)
    writer.configPath = mode === "unreadable" ? configPath + ".missing" : configPath
    writer.shellApi = mode === "unsupported" ? null : mockShell
    writer.write(test.changes(), "saved")
  }
  function completed(success, message) {
    if (done) return
    var test = cases[step]
    if (!check(success === test.success, test.name + ": " + message)) return
    if (!check(calls === test.calls, test.name + ": unexpected API calls " + calls)) return
    if (test.verify && !check(test.verify(),test.name + ": wrong resulting settings")) return
    console.log("ISLES_PASS: " + test.name)
    Qt.callLater(next)
  }

  QtObject {
    id: mockShell
    function updateEntryInline(id, settings) {
      if (!suite.check(id === "io.github.inxeo.isles", "wrong plugin id")) return false
      suite.calls++
      if (suite.mode === "reject") return false
      if (suite.mode === "throw") throw new Error("Simulated host failure")
      suite.live = Store.clone(settings)
      if ((suite.mode === "diskFail" || suite.mode === "unrelated" || suite.mode === "conflict") && suite.calls === 1) {
        if (suite.mode === "unrelated") suite.live = suite.merged(suite.live,{otherPanelValue: "keep"})
        if (suite.mode === "conflict") suite.live = suite.merged(suite.live,{opacity: 91})
        return true
      }
      suite.writeDisk(suite.live)
      return true
    }
  }
  FileView { id: disk; path: suite.configPath; atomicWrites: true }
  Isles.SettingsWriter {
    id: writer
    currentSettings: suite.live
    configPath: suite.configPath
    verificationTimeout: 450
    onCompleted: function(success, message) { suite.completed(success, message) }
  }
  PluginBarApi {
    id: barApi
    pluginId: "io.github.inxeo.isles"
    moduleName: pluginId
    shell: mockShell
    barSize: 32
    foreground: "white"
    fontFamily: "sans-serif"
    vertical: false
  }
  Isles.Panel {
    id: panel
    bar: barApi
    settings: suite.live
    onStatusMessageChanged: {
      if (suite.step !== suite.cases.length || statusMessage === "") return
      if (suite.panelStage === 0) {
        if (!suite.check(statusMessage === "Applied Halo.", "panel action: " + statusMessage)) return
        if (!suite.check(suite.calls === 1 && selectedPreset === "1", "panel did not apply in one update")) return
        console.log("ISLES_PASS: real panel applies preset in one verified update")
        suite.panelStage = 1
        Qt.callLater(function() { panel.savePreset("Integration saved") })
      } else if (suite.panelStage === 1) {
        if (!suite.check(statusMessage === "Saved Integration saved." && selectedPreset === "6", "save through panel: " + statusMessage)) return
        suite.panelStage = 2
        Qt.callLater(function() { panel.applyPreset("2") })
      } else if (suite.panelStage === 2) {
        if (!suite.check(statusMessage === "Applied Pebbles.", "change before update")) return
        suite.panelStage = 3
        Qt.callLater(function() { panel.savePreset("Integration saved") })
      } else if (suite.panelStage === 3) {
        if (!suite.check(statusMessage === "Saved Integration saved." && selectedPreset === "6", "update through panel")) return
        if (!suite.check(Presets.saved(suite.live.savedPresets).length === 1 && suite.live.savedPresets[0].version === 99, "update preserves hidden future record")) return
        console.log("ISLES_PASS: real panel saves and updates a personal preset without losing unsupported records")
        suite.panelStage = 4
        Qt.callLater(function() { panel.savePreset("Delete me") })
      } else if (suite.panelStage === 4) {
        if (!suite.check(statusMessage === "Saved Delete me." && selectedPersonalPreset.name === "Delete me", "deletion target selection")) return
        suite.appearanceBeforeDelete = Presets.snapshot(suite.live)
        suite.panelStage = 5
        Qt.callLater(function() { panel.deletePreset() })
      } else if (suite.panelStage === 5) {
        if (!suite.check(statusMessage === "Deleted Delete me.", "panel deletion: " + statusMessage)) return
        if (!suite.check(Store.equal(suite.appearanceBeforeDelete,Presets.snapshot(suite.live)), "deletion changed appearance")) return
        if (!suite.check(Presets.saved(suite.live.savedPresets).length === 1 && selectedPersonalPreset === null, "deleted preset remains selected")) return
        var callsBefore = suite.calls
        panel.deletePreset()
        if (!suite.check(suite.calls === callsBefore && Presets.builtins().length === 6, "built-in deletion was allowed")) return
        console.log("ISLES_PASS: personal preset deletion preserves appearance and built-ins")
        suite.panelStage = 6
        Qt.callLater(function() { panel.writeSettings({autoContrast: true}, "Contrast enabled") })
      } else if (suite.panelStage === 6) {
        if (!suite.check(suite.live.autoContrast === true, "auto contrast toggle did not persist")) return
        suite.panelStage = 7
        Qt.callLater(function() { panel.applyPreset("0") })
      } else if (suite.panelStage === 7) {
        if (!suite.check(suite.live.autoContrast === true, "preset changed auto contrast toggle")) return
        console.log("ISLES_PASS: auto contrast persists independently of preset changes")
        suite.panelStage = 8
        Qt.callLater(function() { panel.applyPreset("1") })
      } else if (suite.panelStage === 8) {
        if (!suite.check(statusMessage === "Applied Halo." && suite.live.look === "cluster", "undo setup: " + statusMessage)) return
        suite.panelStage = 9
        Qt.callLater(function() { panel.undo() })
      } else if (suite.panelStage === 9) {
        if (!suite.check(statusMessage === "Reverted." && suite.live.look === "glow", "undo did not restore previous look: " + statusMessage)) return
        if (!suite.check(suite.live.autoContrast === true, "undo changed auto contrast")) return
        console.log("ISLES_PASS: undo restores the previous look and leaves auto contrast alone")
        suite.panelStage = 10
        renderTimer.start()
      }
    }
  }

  // Real widget instances in two transparent, noninteractive bar windows. All shell
  // mutations use mockShell and a temporary HOME, never the user's config.
  PanelWindow {
    id: surface
    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    Component.onCompleted: contentItem.opacity = 0
    implicitWidth: 800
    implicitHeight: 32
    Item {
      anchors.fill: parent
      Item {
        x: 2; width: 80; height: 32
        property string region: "left"
        property string moduleName: "io.github.inxeo.isles"
        property var activeItem: widget
        Isles.Widget { id: widget; bar: barApi; settings: suite.renderSettings; width: 80; height: 32 }
      }
    }
  }
  PluginBarApi {
    id: verticalBar
    pluginId: "io.github.inxeo.isles"
    moduleName: pluginId
    shell: mockShell
    barSize: 32
    foreground: "white"
    fontFamily: "sans-serif"
    vertical: true
    position: "left"
  }
  PanelWindow {
    id: verticalSurface
    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    Component.onCompleted: contentItem.opacity = 0
    implicitWidth: 32
    implicitHeight: 800
    Item {
      anchors.fill: parent
      Item {
        y: 2; width: 32; height: 80
        property string region: "left"
        property string moduleName: "io.github.inxeo.isles"
        property var activeItem: verticalWidget
        Isles.Widget { id: verticalWidget; bar: verticalBar; settings: suite.renderSettings; width: 32; height: 80 }
      }
    }
  }
  function findRenderer(item, name) {
    if (String(item).indexOf(name + "_QML") === 0) return item
    for (var i=0; i<item.children.length; i++) {
      var result = findRenderer(item.children[i],name)
      if (result) return result
    }
    return null
  }
  function rendererCount(item, name) {
    var n = String(item).indexOf(name + "_QML") === 0 ? 1 : 0
    for (var i=0; i<item.children.length; i++) n += rendererCount(item.children[i],name)
    return n
  }
  Timer {
    id: renderTimer
    interval: 150
    repeat: true
    onTriggered: {
      if (suite.done) { stop(); return }
      widget.measureHuddle(); verticalWidget.measureHuddle()
      if (!suite.check(widget.drawList.length > 0 && verticalWidget.drawList.length > 0,"slot discovery on both screens")) return
      var preset = suite.renderCases[suite.renderIndex]
      var expected = preset.settings.look === "power" ? "PowerSeg" : preset.settings.look === "brackets" ? "BracketChrome" : "ChromeBox"
      for (var i=0; i<3; i++) {
        var name=["ChromeBox","PowerSeg","BracketChrome"][i]
        if (!suite.check(suite.rendererCount(surface.contentItem,name) === (name === expected ? 1 : 0),"renderer allocation for " + preset.name + ": " + name)) return
      }
      var renderer = suite.findRenderer(surface.contentItem,expected)
      var oldFill = String(renderer.fill)
      Commons.Color.background = suite.renderIndex % 2 ? "#abcdef" : "#234567"
      if (!suite.check(String(renderer.fill) !== oldFill,"theme binding for " + preset.name)) return
      console.log("ISLES_PASS: " + preset.name + " loads on both orientations with one renderer per island and live theme colours")
      suite.renderSettings = suite.merged(suite.renderSettings, {autoContrast: true})
      barApi.barForeground = "black"
      verticalBar.barForeground = "white"
      if (!suite.check(renderer.fill.r > 0.99 && renderer.fill.a >= 0.915, "dark text gets light fill: " + preset.name)) return
      var verticalRenderer = suite.findRenderer(verticalSurface.contentItem, expected)
      if (!suite.check(verticalRenderer.fill.r < 0.01 && verticalRenderer.fill.a >= 0.845, "independent vertical foreground: " + preset.name)) return
      barApi.barForeground = "white"
      if (!suite.check(renderer.fill.r < 0.01, "live foreground changes background: " + preset.name)) return
      suite.renderSettings = suite.merged(suite.renderSettings, {autoContrast: false})
      if (!suite.check(String(renderer.fill) !== String(Qt.rgba(0,0,0,renderer.fill.a)), "off restores theme background: " + preset.name)) return
      if (!suite.check(suite.renderSettings.opacity === preset.settings.opacity, "auto contrast mutated saved opacity")) return
      console.log("ISLES_PASS: auto contrast on/off and independent live text colours for " + preset.name)
      suite.renderIndex++
      if (suite.renderIndex >= suite.renderCases.length) {
        stop()
        var drawing = widget.drawList
        suite.renderSettings = suite.merged(suite.renderSettings, {presetName:"Metadata only", savedPresets:[]})
        Qt.callLater(function() {
          widget.measureHuddle()
          if (!suite.check(widget.drawList === drawing,"metadata rebuilt drawing")) return
          widget.visible = false
          widget.measureHuddle()
          if (!suite.check(widget.drawList.length === 0,"hidden widget kept an island")) return
          widget.visible = true
          widget.measureHuddle()
          if (!suite.check(widget.drawList.length > 0,"reappearing widget did not recover")) return
          console.log("ISLES_PASS: metadata retains renderer; disappearing and returning widgets update geometry")
          var savedOpacity = widget.cfg.opacity
          widget.setLiveOverride("opacity", savedOpacity === 12 ? 13 : 12)
          if (!suite.check(widget.cfg.opacity !== savedOpacity, "live override did not change painted opacity")) return
          if (!suite.check(suite.renderSettings.opacity === savedOpacity, "live override mutated saved opacity")) return
          widget.clearLiveOverride()
          if (!suite.check(widget.cfg.opacity === savedOpacity, "clearing live override did not restore saved opacity")) return
          console.log("ISLES_PASS: live slider override previews without writing settings")
          finishTimer.start()
        })
      } else suite.renderSettings = suite.renderCases[suite.renderIndex].settings
    }
  }
  Timer { id: finishTimer; interval: 250; onTriggered: { console.log("ISLES_INTEGRATION_PASS"); suite.done=true; Qt.quit() } }
  Timer { interval: 15000; running: true; onTriggered: { suite.check(false,"integration timeout") } }
  Timer { interval: 100; running: true; onTriggered: suite.next() }
  Component.onCompleted: {
    live = merged(Presets.builtins()[0].settings,{extension:{keep:true},savedPresets:[{name:"Future",version:99,settings:{future:true}}]})
    writeDisk(live)
    cases = [
      {name:"atomic preset",success:true,calls:1,changes:function(){return merged(Presets.builtins()[1].settings,{presetName:"Halo"})},verify:function(){return live.extension.keep && live.savedPresets[0].version===99}},
      {name:"no-op skips write",success:true,calls:0,changes:function(){return {opacity:live.opacity}}},
      {name:"zero is preserved",success:true,calls:1,changes:function(){return {opacity:0}},verify:function(){return live.opacity===0}},
      {name:"host rejection",mode:"reject",success:false,calls:1,changes:function(){return {opacity:12}},verify:function(){return Store.equal(live,before)}},
      {name:"disk failure restores previous state",mode:"diskFail",success:false,calls:2,changes:function(){return {opacity:12,padding:3}},verify:function(){return Store.equal(live,before)}},
      {name:"retry after recovery",success:true,calls:1,changes:function(){return {opacity:12,padding:3}}},
      {name:"host exception",mode:"throw",success:false,calls:1,changes:function(){return {opacity:13}},verify:function(){return Store.equal(live,before)}},
      {name:"unsupported host",mode:"unsupported",success:false,calls:0,changes:function(){return {opacity:14}},verify:function(){return Store.equal(live,before)}},
      {name:"unreadable verification is bounded",mode:"unreadable",success:false,calls:2,changes:function(){return {opacity:14}},verify:function(){return Store.equal(live,before) && !writer.busy}},
      {name:"recovery preserves unrelated edits",mode:"unrelated",success:false,calls:2,changes:function(){return {opacity:15}},verify:function(){return live.opacity===before.opacity && live.otherPanelValue==="keep"}},
      {name:"recovery preserves conflicting edits",mode:"conflict",success:false,calls:1,changes:function(){return {opacity:16}},verify:function(){return live.opacity===91}}
    ]
  }
}
