import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import "DockModel.js" as DockModel
import "settings"

// An app dock for every workspace layout, with pinned apps, running apps,
// and an application grid.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property var appLibrary: shell ? shell.appLibrary : null
  // A user plugin receives a scoped Shell API. Read the same preference files
  // as the built-in Dock so its settings and the omarchy dock commands agree.
  property var userDockConfig
  property var defaultDockConfig
  property var configuredExtensions: []
  property alias extensions: extensions
  property alias settingsPanel: settingsPanel
  readonly property var dockConfig: userDockConfig || defaultDockConfig || ({})

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
    onLoaded: {
      var config = root.parseDockConfig(text())
      root.userDockConfig = config
      if (config) root.configuredExtensions = config.extensions
    }
    onLoadFailed: function(error) {
      root.userDockConfig = null
      if (error === FileViewError.FileNotFound) root.configuredExtensions = []
    }
  }

  FileView {
    path: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/config/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.defaultDockConfig = root.parseDockConfig(text()) || ({})
    onLoadFailed: root.defaultDockConfig = ({})
  }
  readonly property string position: DockModel.normalizePosition(dockConfig.position)
  readonly property bool vertical: DockModel.isVertical(position)
  readonly property bool autohide: dockConfig.autohide === true

  function setPosition(position) {
    dockPreferenceWriter.enqueue(["omarchy-dock", "position", position])
  }

  function setAutohide(enabled) {
    dockPreferenceWriter.enqueue(["omarchy-dock", "autohide", enabled ? "on" : "off"])
  }

  Process {
    id: dockPreferenceWriter

    // Both commands rewrite shell.json. Finish each write before starting the next.
    property var pending: []

    function enqueue(args) {
      pending.push(args)
      if (!running) writeNext()
    }

    function writeNext() {
      if (running || pending.length === 0) return
      command = pending.shift()
      running = true
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("DogeDock: could not save " + command[1])
      Qt.callLater(writeNext)
    }
  }

  DockExtensions {
    id: extensions

    configured: root.configuredExtensions
  }

  // The dock's order for the session, as desktop ids, set when the user moves
  // an app: a drag moves it, and keeping it in the dock puts it at the end. An
  // app the order does not know yet goes at the end. Pins are saved in this
  // order.
  property var order: []

  // A reorder shows at once rather than when the saved config comes back.
  property var pendingPins: null
  onDockConfigChanged: pendingPins = null

  // Entries that can claim a terminal app's window: those run in a terminal,
  // and those that hand the terminal an app id of their own.
  readonly property var terminalEntries: {
    var values = DesktopEntries.applications.values
    var out = []
    for (var i = 0; i < values.length; i++) {
      var entry = values[i]
      if (entry.runInTerminal || String(entry.execString || "").indexOf("--app-id=") >= 0)
        out.push({ id: entry.id, execString: entry.execString, command: entry.command, runInTerminal: entry.runInTerminal })
    }
    return out
  }

  function entryForAppId(appId) {
    var entry = DesktopEntries.heuristicLookup(appId)
    if (entry) return entry
    var id = DockModel.claimingEntryId(appId, root.terminalEntries)
    return id ? DesktopEntries.byId(id) : null
  }

  // A pinned app that is not installed has nothing to launch, so it is left
  // out until it is. Windows are matched to the desktop entry that claims them.
  readonly property var items: {
    var appsRevision = DesktopEntries.applications.values.length
    var pinned = (root.pendingPins || DockModel.pinnedIds(dockConfig, defaultDockConfig)).filter(function(id) {
      return !!DesktopEntries.byId(id)
    })

    var windows = []
    var toplevels = Hyprland.toplevels.values
    for (var i = 0; i < toplevels.length; i++) {
      var toplevel = toplevels[i].wayland
      if (!toplevel || !toplevel.appId || toplevel.parent) continue
      var entry = root.entryForAppId(toplevel.appId)
      var workspace = toplevels[i].workspace
      windows.push({
        key: entry ? entry.id : toplevel.appId,
        hasEntry: !!entry && !entry.noDisplay,
        workspaceId: workspace ? workspace.id : -1,
        minimized: !!workspace && DockModel.isMinimizedWorkspace(workspace.name),
        address: toplevels[i].address,
        toplevel: toplevel
      })
    }

    return DockModel.orderItems(DockModel.buildItems(pinned, windows), root.order)
  }

  readonly property var itemsByKey: {
    var byKey = {}
    for (var i = 0; i < root.items.length; i++) byKey[root.items[i].key] = root.items[i]
    return byKey
  }

  function itemFor(key) {
    return root.itemsByKey[key] || null
  }

  // The dock's slots follow this model rather than the items list itself, so
  // a slot survives a window opening or closing instead of being rebuilt
  // under the pointer, and a reorder moves slots rather than replacing them.
  property alias itemModel: itemModel

  ListModel { id: itemModel }

  onItemsChanged: syncItemModel()

  function shownKeys() {
    return root.items.map(function(item) { return item.key })
  }

  function syncItemModel() {
    var keys = root.items.map(function(item) { return item.key })
    for (var i = 0; i < keys.length; i++) {
      if (i < itemModel.count && itemModel.get(i).key === keys[i]) continue
      var found = -1
      for (var j = i + 1; j < itemModel.count; j++) {
        if (itemModel.get(j).key === keys[i]) { found = j; break }
      }
      if (found >= 0) itemModel.move(found, i, 1)
      else itemModel.insert(i, { key: keys[i] })
    }
    if (itemModel.count > keys.length) itemModel.remove(keys.length, itemModel.count - keys.length)
  }

  function entryFor(item) {
    return item ? DesktopEntries.byId(item.key) : null
  }

  function nameFor(item) {
    if (!item) return ""
    var entry = entryFor(item)
    return (entry && (root.appLibrary ? root.appLibrary.entryName(entry) : entry.name)) || item.key
  }

  function iconFor(item) {
    var entry = entryFor(item)
    var icon = entry && entry.icon ? entry.icon : (item ? item.key : "")
    return root.appLibrary ? root.appLibrary.iconSource(icon) : Quickshell.iconPath(icon, true)
  }

  function launch(item) {
    root.launchEntry(entryFor(item))
  }

  function launchEntry(entry) {
    if (entry && root.appLibrary) root.appLibrary.launch(entry.id, entry.name)
  }

  function openFiles(key, uris) {
    var entry = root.entryFor(root.itemFor(key))
    if (entry) Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", "--", entry.id + ".desktop"].concat(uris))
  }

  function activate(item) {
    if (!item) return
    if (item.windows.length === 0) {
      root.launch(item)
      return
    }
    var monitor = Hyprland.focusedMonitor
    var workspaceId = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    var index = DockModel.pickWindow(item.windows.map(function(window) {
      return { workspaceId: window.workspaceId, minimized: window.minimized, activated: window.toplevel.activated }
    }), workspaceId)
    root.bringForward(item.windows[index])
  }

  // A window the dock brings forward lands on top of the others, focused; a
  // minimized one first comes back to the workspace in front of the user.
  function bringForward(window) {
    var address = String(window.address || "")
    if (!address) {
      window.toplevel.activate()
      return
    }
    if (address.indexOf("0x") !== 0) address = "0x" + address
    var target = "window = \"address:" + address + "\""
    var steps = []
    var after = []
    if (window.minimized) {
      var monitor = Hyprland.focusedMonitor
      var workspace = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
      if (!(workspace >= 1)) return
      // A restored window is simply there again, without animating in.
      steps.push("hl.dsp.window.set_prop({ prop = \"no_anim\", value = \"1\", " + target + " })")
      steps.push("hl.dsp.window.move({ workspace = \"" + workspace + "\", follow = false, " + target + " })")
      after.push("hl.dsp.window.set_prop({ prop = \"no_anim\", value = \"unset\", " + target + " })")
    }
    steps.push("hl.dsp.focus({ " + target + " })")
    steps.push("hl.dsp.window.alter_zorder({ mode = \"top\", " + target + " })")
    // Move, focus and raise in one compositor call so the original cursor
    // setting is restored before Hyprland handles another input event.
    var script = [
      "local noWarps = hl.get_config('cursor.no_warps')",
      "if not noWarps then hl.config({ cursor = { no_warps = true } }) end",
      "local ok, err = pcall(function()",
      "  for _, action in ipairs({ " + steps.join(", ") + " }) do",
      "    local result = hl.dispatch(action)",
      "    assert(result.ok, result.error)",
      "  end",
      "end)",
      "if not noWarps then hl.config({ cursor = { no_warps = noWarps } }) end",
      "if not ok then error(err) end"
    ].join("\n")
    var command = "hyprctl eval " + Util.shellQuote(script)
    if (after.length > 0) command += "; sleep 0.4; " + after.map(function(step) {
      return "hyprctl dispatch " + Util.shellQuote(step)
    }).join("; ")
    Util.execDetached(command)
  }

  function quit(item) {
    if (!item) return
    var windows = item.windows.slice()
    for (var i = 0; i < windows.length; i++) windows[i].toplevel.close()
  }

  function openApps() {
    if (root.shell && root.manifest) root.shell.summon(root.manifest.id, "{}")
  }

  DockSettingsPanel {
    id: settingsPanel
    dock: root
  }

  readonly property var pinnedKeys: root.pendingPins || DockModel.pinnedIds(root.dockConfig, root.defaultDockConfig)

  function isPinned(key) {
    return root.pinnedKeys.indexOf(key) >= 0
  }

  // Moves an app to a slot in the dock's order, pinning it there; the pins are
  // saved in the new order. The index counts the slots once the app has left
  // its own.
  function placeAt(key, index) {
    if (!key) return
    root.order = DockModel.orderWithKeyAt(root.shownKeys(), key, index)
    var pinned = {}
    root.pinnedKeys.forEach(function(other) { pinned[other] = true })
    pinned[key] = true
    root.savePins(DockModel.pinsInOrder(root.order, pinned, root.pinnedKeys))
  }

  // A reorder shows at once; the saved config catches up after.
  function savePins(pins) {
    root.pendingPins = pins
    Util.execDetached("omarchy-dock pinned " + pins.map(function(id) { return Util.shellQuote(id) }).join(" "))
  }

  function moveItem(fromIndex, toIndex) {
    if (fromIndex !== toIndex) root.placeAt(root.shownKeys()[fromIndex], toIndex)
  }

  // An app dropped before the slot at index, counted as the slots stand.
  function pinAt(key, index) {
    var from = root.shownKeys().indexOf(key)
    root.placeAt(key, from >= 0 && from < index ? index - 1 : index)
  }

  // Keeping an app in the dock puts it at the end; taking one out leaves it in
  // its slot while it still runs.
  function setPinned(key, pinned) {
    if (!key) return
    if (pinned) {
      root.placeAt(key, root.shownKeys().length)
    } else {
      root.pendingPins = root.pinnedKeys.filter(function(other) { return other !== key })
      Util.execDetached("omarchy-dock unpin " + Util.shellQuote(key))
    }
  }

  function refresh() {
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
  }

  Component.onCompleted: syncItemModel()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      // Hyprland's window and workspace lists do not follow fullscreen on
      // their own.
      if (name === "configreloaded" || name === "fullscreen") root.refresh()
    }
  }

  ShellIpc {
    target: "omarchy.dock"

    // The layout commands call this after changing a workspace's mode.
    function refresh(): void { root.refresh() }
    function apps(): void {
      if (root.shell && root.manifest) root.shell.toggle(root.manifest.id, "{}")
    }
  }

  // Capture the dock surfaces' positions for a drag out of the app grid.
  property var dockLayers: ({})

  function refreshDockLayers() {
    root.dockLayers = ({})
    dockLayerQuery.running = true
  }

  Process {
    id: dockLayerQuery

    command: ["hyprctl", "-j", "layers"]
    stdout: StdioCollector { id: dockLayerOutput }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      try { root.dockLayers = JSON.parse(dockLayerOutput.text) } catch (error) {}
    }
  }

  // The grid holds the pointer and reports where it is, and the dock on that
  // screen shows where the app would land.
  function dockOn(screen) {
    var windows = docks.instances
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].screen === screen) return windows[i]
    }
    return null
  }

  function moveExternalDrag(screen, x, y) {
    var windows = docks.instances
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].screen === screen) windows[i].moveExternalDrag(x, y)
      else windows[i].endExternalDrag()
    }
  }

  function dropExternalDrag(screen, x, y, key) {
    var target = root.dockOn(screen)
    if (target) target.dropExternalDrag(x, y, key)
    root.endExternalDrag()
  }

  function endExternalDrag() {
    var windows = docks.instances
    for (var i = 0; i < windows.length; i++) windows[i].endExternalDrag()
  }

  Variants {
    id: docks
    // Wait for the initial settings before the surfaces claim workspace space.
    model: root.userDockConfig !== undefined && root.defaultDockConfig !== undefined ? Quickshell.screens : []

    delegate: Component {
      DockWindow {
        required property var modelData

        screen: modelData
        dock: root
      }
    }
  }

}
