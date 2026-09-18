import QtQuick
import Quickshell
import Quickshell.Io
import "Isles/Presets.js" as Presets
import "Isles/SettingsStore.js" as Store
Scope {
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    onLoaded: {
      var entry = Store.entryFromText(text(),"io.github.inxeo.isles")
      var list = Presets.saved(entry ? entry.savedPresets : null)
      if (!entry || !list.some(function(p){return p.name==="Integration saved"}) || entry.savedPresets[0].version!==99 || list.some(function(p){return p.name==="Delete me"}))
        console.error("ISLES_FAIL: saved presets did not survive restart")
      else console.log("ISLES_RESTART_PASS")
      Qt.quit()
    }
  }
  Timer { interval: 3000; running: true; onTriggered: {console.error("ISLES_FAIL: restart timeout");Qt.quit()} }
}
