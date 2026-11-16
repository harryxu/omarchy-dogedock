pragma ComponentBehavior: Bound

import QtQml
import Quickshell.Io

QtObject {
  id: menu

  required property string rootPath
  required property var openPath
  property var pathStack: [rootPath]
  readonly property string currentPath: pathStack[pathStack.length - 1]
  property var entries: []
  property bool loading: true
  property string loadError: ""
  readonly property string listingScript: decodeURIComponent(String(Qt.resolvedUrl("FolderEntries.py")).slice("file://".length))
  readonly property var menuActions: {
    var actions = [{ id: "open", text: qsTr("Open Current Folder"), iconName: "folder-open" }]
    if (pathStack.length > 1) actions.push({ id: "back", text: qsTr("Back"), iconName: "go-up", enabled: !loading })
    if (loading || loadError || !entries.length) {
      actions.push({
        id: "status",
        text: loading ? qsTr("Loading…") : loadError || qsTr("This folder is empty."),
        enabled: false
      })
    } else {
      entries.forEach(function(entry, index) {
        actions.push({ id: String(index), text: entry.name, iconName: entry.directory ? "folder" : "text-x-generic" })
      })
    }
    return actions
  }

  Component.onCompleted: listing.running = true

  function navigate(next) {
    loading = true
    loadError = ""
    entries = []
    pathStack = next
    listing.running = true
  }

  function triggerAction(id) {
    if (id === "open") {
      openPath(currentPath, true)
      return false
    }
    if (loading) return true
    if (id === "back" && pathStack.length > 1) {
      navigate(pathStack.slice(0, -1))
      return true
    }
    var entry = entries[Number(id)]
    if (!entry) return true
    var path = (currentPath === "/" ? currentPath : currentPath + "/") + entry.name
    if (entry.directory) {
      navigate(pathStack.concat([path]))
      return true
    }
    openPath(path, false)
    return false
  }

  property Process listing: Process {
    command: ["/usr/bin/python", menu.listingScript, menu.currentPath]
    stdout: StdioCollector { id: output }

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && exitStatus === 0) {
        try {
          menu.entries = JSON.parse(output.text)
        } catch (error) {
          menu.loadError = qsTr("Could not read this folder.")
        }
      } else {
        menu.loadError = qsTr("Could not read this folder.")
      }
      menu.loading = false
    }
  }
}
