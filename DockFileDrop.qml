pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

DropArea {
  id: root

  required property var appIds
  required property var appAt

  signal filesDropped(string appId, var uris)

  keys: ["text/uri-list"]
  readonly property bool active: enabled && containsDrag
  readonly property string highlightedApp: active ? compatibleAppAt(drag.x, drag.y) : ""
  property Process check: null
  property var result: null

  function compatibleAppAt(x, y) {
    if (!root.active || !root.result) return ""
    var appId = root.appAt(x, y)
    return root.result.appIds.indexOf(appId) >= 0 ? appId : ""
  }

  function reset() {
    var pending = root.check
    root.check = null
    if (pending) {
      pending.running = false
      pending.destroy()
    }
    root.result = null
  }

  onEntered: function(event) {
    var uris = Array.from(event.urls, String)
    if (!(event.supportedActions & Qt.CopyAction) || uris.length === 0
      || !uris.every(function(uri) { return /^file:\/\/(?:localhost)?\//i.test(uri) })) {
      event.accepted = false
      return
    }

    root.reset()
    var helper = decodeURIComponent(String(Qt.resolvedUrl("FileDrop.py")).slice("file://".length))
    // Probe the batch once as it enters the window. Moving between icons
    // only looks up the result, keeping MIME detection off the UI thread.
    root.check = mimeCheck.createObject(root, {
      command: ["/usr/bin/python", helper, JSON.stringify(root.appIds)].concat(uris),
      running: true
    })
    event.accept(Qt.CopyAction)
  }

  onPositionChanged: function(event) {
    if (root.compatibleAppAt(event.x, event.y)) event.accept(Qt.CopyAction)
    else event.accepted = false
  }

  onDropped: function(event) {
    var appId = root.compatibleAppAt(event.x, event.y)
    if (appId && (event.supportedActions & Qt.CopyAction)) {
      event.accept(Qt.CopyAction)
      root.filesDropped(appId, root.result.uris)
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
