pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

DropArea {
  id: root

  required property var appIds
  required property var slotAt

  signal filesDropped(Item slot, var uris)

  keys: ["text/uri-list"]
  readonly property bool active: enabled && containsDrag
  readonly property Item highlightedSlot: active ? compatibleSlotAt(drag.x, drag.y) : null
  property var sourceUris: []
  property Process check: null
  property var result: null

  function compatibleSlotAt(x, y) {
    if (!root.active || !root.sourceUris.length) return null
    var slot = root.slotAt(x, y)
    if (!slot) return null
    if (slot.dropExtensionId) return slot
    return root.result && root.result.appIds.indexOf(slot.appId) >= 0 ? slot : null
  }

  function reset() {
    var pending = root.check
    root.check = null
    if (pending) {
      pending.running = false
      pending.destroy()
    }
    root.result = null
    root.sourceUris = []
  }

  onEntered: function(event) {
    var uris = Array.from(event.urls, String)
    if (!(event.supportedActions & Qt.CopyAction) || uris.length === 0
      || !uris.every(function(uri) { return /^file:\/\/(?:localhost)?\//i.test(uri) })) {
      event.accepted = false
      return
    }

    root.reset()
    root.sourceUris = uris
    if (root.appIds.length) {
      var helper = decodeURIComponent(String(Qt.resolvedUrl("FileDrop.py")).slice("file://".length))
      // The MIME probe is for apps. Extensions receive local URIs directly.
      root.check = mimeCheck.createObject(root, {
        command: ["/usr/bin/python", helper, JSON.stringify(root.appIds)].concat(uris),
        running: true
      })
    }
    // Copy negotiates URI transfer without asking the source to delete files.
    event.accept(Qt.CopyAction)
  }

  onPositionChanged: function(event) {
    if (root.compatibleSlotAt(event.x, event.y) && (event.supportedActions & Qt.CopyAction)) event.accept(Qt.CopyAction)
    else event.accepted = false
  }

  onDropped: function(event) {
    var slot = root.compatibleSlotAt(event.x, event.y)
    if (slot && (event.supportedActions & Qt.CopyAction)) {
      event.accept(Qt.CopyAction)
      root.filesDropped(slot, slot.dropExtensionId ? root.sourceUris : root.result.uris)
    } else {
      event.accepted = false
    }
    root.reset()
  }

  onExited: root.reset()
  onEnabledChanged: if (!enabled) root.reset()

  Component {
    id: mimeCheck

    Process {
      id: probe

      stdout: StdioCollector { id: output }
      onExited: function(exitCode) {
        if (root.check !== probe) return
        if (exitCode === 0) root.result = JSON.parse(output.text)
        root.check = null
        probe.destroy()
      }
    }
  }
}
