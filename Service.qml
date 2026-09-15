import QtQuick

// Chrome is painted inside the bar window (behind widgets) by Widget.qml.
// A separate layer-shell surface sat on top of left/right bars and washed
// the icons out. This service only keeps the plugin kind valid.
Item {
  property var shell: null
  property var manifest: null
}
