import QtQuick

// Provide layout space for AppGrid on the offscreen platform.
Item {
  id: surface

  property bool shown: false
  property var screen: null
  property Item contentItem: surface

  width: 1280
  height: 800
  visible: shown
}
