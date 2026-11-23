pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  property int itemCount: -1
  readonly property bool canEmpty: itemCount > 0 && !operation.running
  readonly property var icons: [{
    id: "trash",
    iconName: itemCount > 0 ? "user-trash-full" : "user-trash",
    tooltip: itemCount < 0 ? qsTr("Trash (status unavailable)") : qsTr("Trash"),
    acceptsFiles: !operation.running
  }]

  onCanEmptyChanged: if (!canEmpty) confirmation.dismiss()

  Component.onCompleted: {
    statusQuery.running = true
    monitor.running = true
  }

  function iconClicked(iconId, button, anchor) {
    confirmation.dismiss()
    if (button === "left") {
      if (anchor.current) anchor.current.close()
      openTrash.running = true
    } else if (anchor.current) {
      anchor.current.close()
    } else {
      var view = anchor.show(trashMenu, {}, { onOutsideClick: function(handle) { handle.close() } })
      if (view) view.item.dismiss = view.close
    }
  }

  function dropFiles(iconId, uris) {
    if (operation.running || !uris.length) return
    startOperation(["gio", "trash", "--"].concat(Array.from(new Set(uris))),
      qsTr("Could not move some items to the Trash."))
  }

  function startOperation(command, failureMessage) {
    operation.failureMessage = failureMessage
    operation.command = command
    operation.running = true
  }

  function reportFailure(message, details) {
    var error = details.trim()
    console.warn("DogeDock Trash: " + message + (error ? "\n" + error : ""))
    var body = error.slice(0, 600).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    Quickshell.execDetached(["notify-send", "--app-name=DogeDock", "--icon=user-trash", "--", message, body])
  }

  property Component trashMenu: Component {
    TrashMenu {
      canEmpty: root.canEmpty
      onOpenRequested: root.openTrash.running = true
      onEmptyRequested: function(screenName) {
        if (root.canEmpty)
          root.confirmation.targetScreen = Quickshell.screens.find(function(screen) { return screen.name === screenName }) || null
      }
    }
  }

  property TrashConfirmation confirmation: TrashConfirmation {
    onAccepted: if (root.canEmpty)
      root.startOperation(["gio", "trash", "--empty"], qsTr("Could not empty the Trash."))
  }

  property Process openTrash: Process {
    command: ["gio", "open", "trash:///"]
    stderr: StdioCollector { id: openError }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || exitStatus !== 0) root.reportFailure(qsTr("Could not open the Trash."), openError.text)
    }
  }

  property Process operation: Process {
    property string failureMessage: ""

    stderr: StdioCollector { id: operationError }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || exitStatus !== 0) root.reportFailure(failureMessage, operationError.text)
      root.refreshTimer.restart()
    }
  }

  property Process statusQuery: Process {
    command: ["gio", "info", "-a", "trash::item-count", "trash:///"]
    stdout: StdioCollector { id: statusOutput }
    onExited: function(exitCode, exitStatus) {
      var count = /^\s*trash::item-count:\s*(\d+)\s*$/m.exec(statusOutput.text)
      root.itemCount = exitCode === 0 && exitStatus === 0 && count ? Number(count[1]) : -1
    }
  }

  property Process monitor: Process {
    command: ["gio", "monitor", "--dir=trash:///"]
    stdout: SplitParser { onRead: if (!root.refreshTimer.running) root.refreshTimer.start() }
  }

  property Timer refreshTimer: Timer {
    interval: 150
    onTriggered: {
      if (root.statusQuery.running) restart()
      else root.statusQuery.running = true
    }
  }

  // Recover if GVfs was unavailable at startup or a backend missed an event.
  property Timer refreshFallback: Timer {
    interval: 30000
    repeat: true
    running: true
    onTriggered: {
      if (!root.monitor.running) root.monitor.running = true
      if (!root.refreshTimer.running) root.refreshTimer.start()
    }
  }
}
