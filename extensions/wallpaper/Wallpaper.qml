pragma ComponentBehavior: Bound

import QtQml
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

QtObject {
  id: root

  readonly property var icons: config.showDockIcon ? [{
    id: "wallpaper",
    iconName: "preferences-desktop-wallpaper",
    tooltip: qsTr("Wallpaper")
  }] : []
  readonly property string configPath: {
    var configHome = Quickshell.env("XDG_CONFIG_HOME") || ""
    return (configHome.startsWith("/") ? configHome : Quickshell.env("HOME") + "/.config")
      + "/harryxu.dogedock/wallpaper.json"
  }
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("Wallpaper.py")).slice("file://".length))
  readonly property bool busy: request !== null
  readonly property bool menuBusy: menuWorker.running
  readonly property bool canStep: ready && !busy && config.mode === "directory" && !!config.directory
  property bool ready: false
  property var config: normalizedSettings({})
  property var request: null
  property var pendingMenuSave: null
  property string lastPath: ""
  property string error: ""

  readonly property Component settingsPanel: Component {
    WallpaperSettings {
      wallpaper: root
    }
  }

  property Component dockMenu: Component {
    WallpaperMenu { wallpaper: root }
  }

  function iconClicked(iconId, button, anchor) {
    if (anchor.current) {
      if (!anchor.current.item.dialogOpen) anchor.current.close()
      return
    }
    var view = anchor.show(dockMenu, {}, {
      onOutsideClick: function(handle) {
        if (!handle.item.dialogOpen) handle.close()
      }
    })
    if (view) view.item.dismiss = view.close
  }

  function localPath(value) {
    return typeof value === "string" && value.startsWith("/") && value.indexOf(String.fromCharCode(0)) < 0
      ? value : ""
  }

  function pathFromUrl(url) {
    try {
      var uri = String(url)
      if (uri.startsWith("file:///")) return localPath(decodeURIComponent(uri.slice("file://".length)))
    } catch (error) {}
    return ""
  }

  function normalizedSettings(value) {
    var minutes = value.minutes
    return {
      mode: value.mode === "directory" ? "directory" : "single",
      image: localPath(value.image),
      directory: localPath(value.directory),
      order: value.order === "random" ? "random" : "filename",
      showDockIcon: value.showDockIcon === true,
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

  function save(settings, fromMenu) {
    if (!ready) return
    if (busy) {
      if (fromMenu) pendingMenuSave = settings
      return
    }
    var next = normalizedSettings(Object.assign({}, config, settings))
    if (!(next.mode === "directory" ? next.directory : next.image)) return
    var sameDirectory = next.mode === "directory" && config.mode === "directory" && next.directory === config.directory
    rotation.stop()
    run(next, sameDirectory ? "save-only" : "save", true, fromMenu)
  }

  function savePreferences(changes, fromMenu) {
    if (!ready || busy) return
    run(normalizedSettings(Object.assign({}, config, changes)), "save-only", false, fromMenu)
  }

  function advance() {
    if (canStep) run(config, "rotate")
  }

  function step(direction) {
    if (!canStep) return
    rotation.stop()
    run(config, direction < 0 ? "previous" : "next", true)
  }

  function run(settings, operation, restartRotation, fromMenu) {
    request = { settings: settings, operation: operation, restartRotation: !!restartRotation, fromMenu: !!fromMenu }
    worker.started = false
    worker.command = ["/usr/bin/python", helper, configPath, JSON.stringify(settings), operation, lastPath]
    worker.running = true
  }

  function finish(result) {
    if (!request) return
    var restartRotation = request.restartRotation
    if (result.saved) {
      config = request.settings
      if (request.operation === "save") lastPath = ""
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
    if (error && request.fromMenu) notifyFailure(error)
    request = null
    if (restartRotation && config.mode === "directory" && config.directory) rotation.restart()
    if (pendingMenuSave) {
      var settings = pendingMenuSave
      pendingMenuSave = null
      save(settings, true)
    }
  }

  function notifyFailure(message) {
    Quickshell.execDetached(["notify-send", "--app-name=DogeDock", "--icon=preferences-desktop-wallpaper", "--", qsTr("Wallpaper"), message])
  }

  function openDirectory() {
    if (config.mode !== "directory" || !config.directory) return
    runMenuCommand(["gio", "open", Commons.Util.fileUrl(config.directory)], qsTr("Could not open the wallpaper directory."))
  }

  function exportWallpaper(source, destination) {
    if (!localPath(source) || !localPath(destination)) return
    runMenuCommand(["/usr/bin/python", helper, "export", source, destination], qsTr("Could not save a copy of the wallpaper."))
  }

  function runMenuCommand(command, failureMessage) {
    if (menuWorker.running) return
    menuWorker.failureMessage = failureMessage
    menuWorker.started = false
    menuWorker.command = command
    menuWorker.running = true
  }

  property Process menuWorker: Process {
    id: menuWorker

    property string failureMessage
    property bool started: false

    onStarted: started = true
    onRunningChanged: if (!running && !started) root.notifyFailure(failureMessage)
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || exitStatus !== 0) root.notifyFailure(failureMessage)
    }
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
