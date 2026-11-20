pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  readonly property var icons: []
  readonly property string configPath: {
    var configHome = Quickshell.env("XDG_CONFIG_HOME") || ""
    return (configHome.startsWith("/") ? configHome : Quickshell.env("HOME") + "/.config")
      + "/harryxu.dogedock/wallpaper.json"
  }
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("Wallpaper.py")).slice("file://".length))
  readonly property bool busy: request !== null
  property bool ready: false
  property var config: normalizedSettings({})
  property var request: null
  property string lastPath: ""
  property string error: ""

  readonly property Component settingsPanel: Component {
    WallpaperSettings {
      wallpaper: root
    }
  }

  function localPath(value) {
    return typeof value === "string" && value.startsWith("/") && value.indexOf(String.fromCharCode(0)) < 0
      ? value : ""
  }

  function normalizedSettings(value) {
    var minutes = value.minutes
    return {
      mode: value.mode === "directory" ? "directory" : "single",
      image: localPath(value.image),
      directory: localPath(value.directory),
      minutes: Number.isInteger(minutes) && minutes >= 1 && minutes <= 1440 ? minutes : 15
    }
  }

  function loadSettings(text) {
    try {
      var saved = JSON.parse(text)
      if (!saved || typeof saved !== "object" || Array.isArray(saved)) throw new Error()
      config = normalizedSettings(saved)
    } catch (error) {
      root.error = qsTr("Could not read the saved wallpaper settings.")
    }
    ready = true
    if (config.mode === "directory" && config.directory) rotation.start()
  }

  function save(settings) {
    if (!ready || busy) return
    var next = normalizedSettings(settings)
    if (!(next.mode === "directory" ? next.directory : next.image)) return
    rotation.stop()
    run(next, true)
  }

  function advance() {
    if (ready && !busy && config.mode === "directory" && config.directory)
      run(config, false)
  }

  function run(settings, save) {
    request = { settings: settings, save: save }
    worker.started = false
    worker.command = ["/usr/bin/python", helper, configPath, JSON.stringify(settings), save ? "save" : "rotate", lastPath]
    worker.running = true
  }

  function finish(result) {
    if (!request) return
    var wasSave = request.save
    if (result.saved) {
      config = request.settings
      lastPath = ""
    }
    if (result.path) lastPath = result.path
    var messages = {
      image: qsTr("Choose a readable image."),
      directory: qsTr("Could not read the wallpaper directory."),
      empty: qsTr("There are no supported images in this directory."),
      save: qsTr("Could not save wallpaper settings."),
      apply: qsTr("Could not set the wallpaper.")
    }
    error = messages[result.error] || ""
    request = null
    if (wasSave && config.mode === "directory" && config.directory) rotation.restart()
  }

  property FileView settingsFile: FileView {
    path: root.configPath
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: function(error) {
      if (error !== FileViewError.FileNotFound)
        root.error = qsTr("Could not read the saved wallpaper settings.")
      root.ready = true
    }
  }

  property Timer rotation: Timer {
    interval: root.config.minutes * 60 * 1000
    repeat: true
    onTriggered: root.advance()
  }

  property Process worker: Process {
    id: worker

    property bool started: false
    stdout: StdioCollector { id: resultOutput }

    onStarted: started = true
    onRunningChanged: {
      if (!running && !started) root.finish({ error: "apply" })
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0 && exitStatus === 0) {
        try {
          var result = JSON.parse(resultOutput.text)
          root.finish(result)
          return
        } catch (error) {}
      }
      root.finish({ error: "apply" })
    }
  }
}
