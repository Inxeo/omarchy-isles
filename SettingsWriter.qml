import QtQuick
import Quickshell
import Quickshell.Io
import "SettingsStore.js" as Store

Item {
  id: root
  property var shellApi: null
  property var currentSettings: ({})
  property string moduleName: "io.github.inxeo.isles"
  property string configPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
  property int verificationTimeout: 2000
  readonly property bool busy: phase !== ""
  property string phase: ""
  property var transaction: null
  property string successMessage: ""
  signal completed(bool success, string message)

  function finish(success, message) {
    deadline.stop()
    poll.stop()
    phase = ""
    transaction = null
    completed(success, message)
  }

  function write(changes, message) {
    if (busy) return
    var next = Store.plan(currentSettings, changes)
    if (!next.keys.length) { completed(true, message || ""); return }
    if (!shellApi || typeof shellApi.updateEntryInline !== "function") {
      completed(false, "This Omarchy version cannot save Isles settings safely. Nothing was changed.")
      return
    }
    transaction = next
    successMessage = message || ""
    phase = "applying"
    try {
      if (!shellApi.updateEntryInline(moduleName, next.target)) {
        recover()
        return
      }
    } catch (e) {
      recover()
      return
    }
    beginVerification()
  }

  function beginVerification() {
    if (!busy) return
    deadline.restart()
    poll.restart()
    persisted.reload()
  }

  function verify(text) {
    if (!busy || !transaction) return
    var expected = phase === "restoring" ? transaction.before : transaction.target
    var entry = Store.entryFromText(text, moduleName)
    if (!Store.matches(entry, expected, transaction.keys)
        || !Store.matches(currentSettings, expected, transaction.keys)) return
    if (phase === "restoring") finish(false, "Could not save the change. Previous settings restored; please try again.")
    else finish(true, successMessage)
  }

  function recover() {
    if (!transaction) return
    var previous = Store.restore(currentSettings, transaction)
    if (!previous) {
      // Rejection before any live change needs no rollback. A concurrent edit
      // is also left intact rather than being overwritten with an old snapshot.
      finish(false, "Save was not confirmed. Current settings were left intact; please try again.")
      return
    }
    phase = "restoring"
    try { shellApi.updateEntryInline(moduleName, previous) }
    catch (e) {
      finish(false, "Save failed and previous settings could not be restored. Reopen Isles and check the settings.")
      return
    }
    beginVerification()
  }

  FileView {
    id: persisted
    path: root.busy ? root.configPath : ""
    printErrors: false
    onLoaded: root.verify(text())
  }

  Timer {
    id: poll
    interval: 100
    repeat: true
    onTriggered: persisted.reload()
  }

  Timer {
    id: deadline
    interval: root.verificationTimeout
    onTriggered: {
      if (root.phase === "restoring")
        root.finish(false, "Could not confirm saving or recovery. Reopen Isles and check the settings.")
      else root.recover()
    }
  }
}
