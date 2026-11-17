import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "DockModel.js" as DockModel

Scope {
  id: root

  // UI callers share this instance for live preferences and persistence.
  readonly property bool ready: userDockConfig !== undefined && defaultDockConfig !== undefined
    && privateConfig !== undefined
  readonly property var configuredExtensions: privateConfig ? privateConfig.extensions : undefined
  readonly property var pinnedIds: pendingPins || DockModel.pinnedIds(dockConfig, defaultDockConfig)
  readonly property string position: DockModel.normalizePosition(dockConfig.position)
  readonly property bool autohide: dockConfig.autohide === true
  readonly property int sizeLevel: requestedSizeLevel || savedSizeLevel
  property bool savingExtension: false
  property string extensionSaveError: ""

  function setPosition(position) {
    dockPreferenceWriter.enqueue(["omarchy-dock", "position", position])
  }

  function setAutohide(enabled) {
    dockPreferenceWriter.enqueue(["omarchy-dock", "autohide", enabled ? "on" : "off"])
  }

  function setPinnedIds(pins) {
    root.pendingPins = pins
    Util.execDetached("omarchy-dock pinned " + pins.map(function(id) { return Util.shellQuote(id) }).join(" "))
  }

  function unpin(id) {
    root.pendingPins = root.pinnedIds.filter(function(pinnedId) { return pinnedId !== id })
    Util.execDetached("omarchy-dock unpin " + Util.shellQuote(id))
  }

  function setSizeLevel(level) {
    if (!DockModel.isSizeLevel(level)) return
    if (level === root.sizeLevel) return
    root.requestedSizeLevel = level
    root.sizeWritesPending++
    writePrivateSettings(".sizeLevel = $level", ["--argjson", "level", String(level)], function(exitCode) {
      root.sizeWritesPending--
      if (root.sizeWritesPending !== 0) return
      if (exitCode !== 0) root.requestedSizeLevel = 0
      root.sizeReloadPending = true
      privateSettingsFile.reload()
    })
  }

  // Callers resolve the extension reference and validate its manifest settings.
  function setExtensionEnabled(reference, enabled) {
    if (typeof enabled !== "boolean") return
    writeExtension(reference, ".enabled = $value", enabled, "", !reference.startsWith("/"))
  }

  function addExternalExtension(reference) {
    writeExtension(reference, ".enabled = $value", true, "", true)
  }

  function removeExternalExtension(reference) {
    if (!reference.startsWith("/")) return
    writeExtension(reference, "", null, "", false, true)
  }

  function setExtensionSetting(reference, key, value) {
    writeExtension(reference, '.settings |= ((if type == "object" then . else {} end) | .[$key] = $value)',
      value, key, false)
  }

  // A user plugin receives a scoped Shell API. Read the same preference files
  // as the built-in Dock so its settings and the omarchy dock commands agree.
  property var userDockConfig
  property var defaultDockConfig
  property var privateConfig
  readonly property string privateConfigDirectory: {
    var configHome = Quickshell.env("XDG_CONFIG_HOME") || ""
    return (configHome.startsWith("/") ? configHome : Quickshell.env("HOME") + "/.config")
      + "/harryxu.dogedock"
  }
  readonly property string privateConfigPath: privateConfigDirectory + "/settings.json"
  property bool privateConfigDirectoryReady: false
  readonly property var dockConfig: userDockConfig || defaultDockConfig || ({})
  property var pendingPins: null

  onDockConfigChanged: pendingPins = null

  function parseDockConfig(text) {
    try {
      var config = JSON.parse(text)
      if (Util.isPlainObject(config) && config.version === 1)
        return Util.isPlainObject(config.dock) ? config.dock : ({})
    } catch (error) {}
    return null
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.userDockConfig = root.parseDockConfig(text())
    onLoadFailed: root.userDockConfig = null
  }

  FileView {
    path: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.defaultDockConfig = root.parseDockConfig(text()) || ({})
    onLoadFailed: root.defaultDockConfig = ({})
  }

  Process {
    // FileView can watch a missing file once its parent directory exists.
    command: ["mkdir", "-p", "-m", "700", "--", root.privateConfigDirectory]
    running: true
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("DogeDock: could not prepare settings directory")
      root.privateConfigDirectoryReady = true
    }
  }

  FileView {
    id: privateSettingsFile
    path: root.privateConfigDirectoryReady ? root.privateConfigPath : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var config
      try {
        config = JSON.parse(text())
      } catch (error) {}
      var valid = Util.isPlainObject(config)
      if (valid) root.privateConfig = config
      else {
        console.warn("DogeDock: settings.json must contain a JSON object")
        if (!root.privateConfig) root.privateConfig = ({})
      }
      root.finishPrivateSettingsLoad(valid)
    }
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound || !root.privateConfig) root.privateConfig = ({})
      root.finishPrivateSettingsLoad(false)
    }
  }

  readonly property int savedSizeLevel: DockModel.normalizeSizeLevel(privateConfig ? privateConfig.sizeLevel : undefined)
  property int requestedSizeLevel: 0
  property int sizeWritesPending: 0
  property bool sizeReloadPending: false
  property bool extensionReloadPending: false

  function finishPrivateSettingsLoad(success) {
    if (root.extensionReloadPending) root.finishExtensionSave(success)
    if (root.sizeReloadPending && root.sizeWritesPending === 0) {
      root.sizeReloadPending = false
      root.requestedSizeLevel = 0
    }
  }

  function writeExtension(reference, mutation, value, key, allowCreate, remove) {
    if (root.savingExtension) return
    root.savingExtension = true
    root.extensionSaveError = ""
    var entry = reference.startsWith("/") ? { path: reference } : { id: reference }
    var update = [
      'def reference: if type == "string" then .',
      '  elif type == "object" and (has("path") != has("id")) then (.path // .id) else null end;',
      'def trimpath: sub("/+$"; "") | if . == "" then "/" else . end;',
      'def matches: reference | if type != "string" then false',
      '  elif startswith("/") then trimpath == $entry.path',
      '  else . == $entry.id end;',
      '.extensions |= ((if . == null then [] else . end)',
      '  | if type != "array" then error("extensions must be an array")',
      '    elif $remove then map(select(matches | not))',
      '    elif any(.[]; matches) then map(if matches then',
      '      (if type == "string" then $entry else . end) | (' + (mutation || ".") + ')',
      '      else . end)',
      '    elif $allowCreate then . + [($entry | (' + (mutation || ".") + '))]',
      '    else error("extension entry was removed") end)'
    ].join("\n")
    writePrivateSettings(update, ["--argjson", "entry", JSON.stringify(entry), "--argjson", "value", JSON.stringify(value),
      "--arg", "key", key, "--argjson", "allowCreate", String(allowCreate), "--argjson", "remove", String(remove === true)], function(exitCode) {
      if (exitCode !== 0) {
        root.finishExtensionSave(false)
        return
      }
      root.extensionReloadPending = true
      privateSettingsFile.reload()
    })
  }

  function finishExtensionSave(success) {
    root.extensionReloadPending = false
    root.savingExtension = false
    if (!success) root.extensionSaveError = qsTr("Could not save extension settings.")
  }

  function writePrivateSettings(filter, args, callback) {
    // Lock the read and rewrite together and stage the file beside the destination.
    var script = [
      'config="$1"; filter="$2"; shift 2',
      'umask 077',
      'mkdir -p -- "${config%/*}"',
      'exec 9>"$config.lock"',
      'flock -x 9',
      'if [[ -e $config || -L $config ]]; then exec 8<"$config"; else exec 8<<<"{}"; fi',
      'temp=$(mktemp -- "$config.XXXXXX")',
      'trap \'rm -f -- "$temp"\' EXIT',
      'jq -s -e "$@" \'(if length == 1 and (.[0] | type == "object") then .[0] else error("expected one settings object") end) | \'"$filter" <&8 > "$temp"',
      'mv -T -- "$temp" "$config"'
    ].join("\n")
    dockPreferenceWriter.enqueue(["bash", "-ec", script, "dogedock-settings", root.privateConfigPath, filter].concat(args), callback)
  }

  Process {
    id: dockPreferenceWriter

    // Finish each settings write before starting the next.
    property var pending: []
    property var completed: null

    function enqueue(args, callback) {
      pending.push({ args: args, callback: callback })
      if (!running) writeNext()
    }

    function writeNext() {
      if (running || pending.length === 0) return
      var write = pending.shift()
      completed = write.callback
      command = write.args
      running = true
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("DogeDock: could not save Dock settings")
      if (completed) completed(exitCode)
      Qt.callLater(writeNext)
    }
  }
}
