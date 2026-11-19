pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import qs.Commons

QtObject {
  id: root

  required property var settings

  readonly property string copyScript: decodeURIComponent(String(Qt.resolvedUrl("FolderCopy.py")).slice("file://".length))
  readonly property var icons: settings.directories.map(function(path) {
    return {
      id: path,
      iconName: "folder",
      tooltip: path,
      acceptsFiles: true
    }
  })

  function iconClicked(iconId, button, anchor) {
    if (settings.directories.indexOf(iconId) < 0) return
    var contextMenu = button === "right"
    if (anchor.current && anchor.current.item.contextMenu === contextMenu) {
      anchor.current.close()
      return
    }
    var view = anchor.show(folderMenu, { rootPath: iconId, contextMenu: contextMenu }, {
      onOutsideClick: function(handle) { handle.close() }
    })
    if (view) view.item.dismiss = view.close
  }

  function openPath(path, directory) {
    opener.createObject(root, { path: path, directory: directory })
  }

  function dropFiles(iconId, uris) {
    if (settings.directories.indexOf(iconId) < 0 || !uris.length) return
    var operation = copier.createObject(root, {
      request: JSON.stringify({ directory: iconId, uris: Array.from(new Set(uris)) })
    })
    operation.running = true
  }

  function notifyFailure(title, details) {
    var escapedDetails = details.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    Quickshell.execDetached(["notify-send", "--app-name=DogeDock", "--icon=folder", "--", title, escapedDetails])
  }

  property Component folderMenu: Component {
    FolderMenu {
      openPath: root.openPath
    }
  }

  property Component opener: Component {
    Process {
      id: operation

      required property string path
      required property bool directory

      command: directory ? ["bash", "-c", '[[ -d "$1" ]] || exit 66; exec gio open "$2"',
        "dogedock-folder", path, Util.fileUrl(path)] : ["gio", "open", Util.fileUrl(path)]
      running: true

      onExited: function(exitCode, exitStatus) {
        if (exitCode !== 0 || exitStatus !== 0) {
          var title = directory
            ? (exitCode === 66 ? qsTr("Folder is unavailable.") : qsTr("Could not open folder."))
            : qsTr("Could not open file.")
          root.notifyFailure(title, path)
        }
        operation.destroy()
      }
    }
  }

  property Component copier: Component {
    Process {
      id: copy

      required property string request
      property bool started: false

      command: ["/usr/bin/python", root.copyScript]
      stdinEnabled: true
      onStarted: {
        copy.started = true
        copy.write(copy.request)
        copy.stdinEnabled = false
      }
      onRunningChanged: if (!running && !started) finish(true)
      onExited: function(exitCode, exitStatus) { finish(exitCode !== 0 || exitStatus !== 0) }

      function finish(failed) {
        if (failed) root.notifyFailure(qsTr("Could not copy some files."),
          qsTr("Check that the destination is writable and the files do not already exist there."))
        copy.destroy()
      }
    }
  }
}
