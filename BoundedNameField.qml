import QtQuick
import QtQuick.Controls as QQC
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Single-line name field that never lets Qt read an unbounded clipboard
// payload. TextArea only checks formats; paste goes through clipboard_read.py.
QQC.TextArea {
  id: root

  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property int maximumLength: 40
  signal accepted()

  readonly property var borderSpec: Border.controlSpec(activeFocus ? "focus" : (hovered ? "hover-cursor" : "normal"), foreground, accent)
  readonly property string helperPath: {
    var s = Qt.resolvedUrl("clipboard_read.py").toString()
    if (s.indexOf("file://") === 0) s = s.slice(7)
    if (s.indexOf("localhost/") === 0) s = s.slice(9)
    try { return decodeURIComponent(s) } catch (e) { return s }
  }

  textFormat: TextEdit.PlainText
  wrapMode: TextEdit.NoWrap
  clip: true
  selectByMouse: true
  activeFocusOnTab: true
  implicitHeight: font.pixelSize + topPadding + bottomPadding
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  color: foreground
  selectionColor: Style.selectionFillFor(foreground, accent)
  selectedTextColor: foreground
  placeholderTextColor: Qt.darker(foreground, 1.6)
  leftPadding: Style.spacing.controlPaddingX + Border.left(borderSpec)
  rightPadding: Style.spacing.controlPaddingX + Border.right(borderSpec)
  topPadding: Style.spacing.inputPaddingY + Border.top(borderSpec)
  bottomPadding: Style.spacing.inputPaddingY + Border.bottom(borderSpec)
  background: BorderSurface {
    color: Style.controlFill(root.activeFocus, root.hovered, root.foreground, root.accent)
    borderSpec: root.borderSpec
    radius: Style.cornerRadius
  }

  QQC.ContextMenu.menu: null
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.matches(StandardKey.Paste) || (event.key === Qt.Key_Insert && (event.modifiers & Qt.ShiftModifier))) {
      root.boundedPaste(false)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.accepted()
      event.accepted = true
    }
  }

  onTextChanged: {
    if (root.length > root.maximumLength)
      root.remove(root.maximumLength, root.length)
    if (root.text.indexOf("\n") >= 0 || root.text.indexOf("\r") >= 0)
      root.text = root.text.replace(/[\r\n]+/g, " ")
  }

  function boundedPaste(primary) {
    if (readOnly || !enabled || reader.running) return
    reader.previousText = text
    reader.start = selectionStart
    reader.end = selectionEnd
    reader.cursor = cursorPosition
    reader.command = ["python3", helperPath, String(Math.max(1, Math.min(1024, maximumLength * 4))), primary ? "primary" : "clipboard"]
    reader.running = true
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    cursorShape: Qt.IBeamCursor
    onPressed: function(mouse) {
      root.forceActiveFocus()
      root.cursorPosition = root.positionAt(mouse.x, mouse.y)
    }
    onClicked: root.boundedPaste(true)
  }

  Process {
    id: reader
    property string previousText
    property int start
    property int end
    property int cursor
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(code, status) {
      if (code !== 0 || !root.activeFocus || root.readOnly || !root.enabled
          || root.text !== previousText || root.cursorPosition !== cursor
          || root.selectionStart !== start || root.selectionEnd !== end) return
      var value = ""
      try { value = JSON.parse(output.text) } catch (e) { return }
      if (typeof value !== "string" || !value) return
      value = value.replace(/[\r\n\u2028\u2029]+/g, " ")
      var room = root.maximumLength - (root.length - (end - start))
      if (room <= 0) return
      value = value.slice(0, room)
      if (!value) return
      root.remove(start, end)
      root.insert(start, value)
      root.cursorPosition = start + value.length
    }
  }
}
