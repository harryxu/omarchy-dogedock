pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import qs.Commons

QtObject {
  id: root

  required property var settings

  readonly property var icons: settings.directories.map(function(path) {
    return { id: path, iconName: "folder", tooltip: path }
  })

  function activate(iconId) {
    if (settings.directories.indexOf(iconId) >= 0)
      opener.createObject(root, { directory: iconId })
  }

  property Component opener: Component {
    Process {
      id: operation

      required property string directory

      command: ["bash", "-c", '[[ -d "$1" ]] || exit 66; exec gio open "$2"',
        "dogedock-folder", directory, Util.fileUrl(directory)]
      running: true

      onExited: function(exitCode, exitStatus) {
        if (exitCode !== 0 || exitStatus !== 0) {
          var title = exitCode === 66 ? qsTr("Folder is unavailable.") : qsTr("Could not open folder.")
          var path = directory.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
          Quickshell.execDetached(["notify-send", "--app-name=DogeDock", "--icon=folder", "--", title, path])
        }
        operation.destroy()
      }
    }
  }
}
