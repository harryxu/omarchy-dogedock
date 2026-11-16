import QtQuick
import Quickshell
import qs.Commons as Commons
import "DogeDock" as Doge
import "DogeDock/IconGeometry.js" as Geometry

ShellRoot {
  id: test

  readonly property string fixture: Quickshell.env("DOGEDOCK_TEST_ROOT")
  readonly property string firstPath: fixture + "/First # extension"
  readonly property string secondPath: fixture + "/Second"
  readonly property var trash: dock.extensions.instanceFor("trash")
  readonly property var first: external.instanceFor("example.first")
  property var originalFirst: null
  property int step: 0
  property int attempts: 0

  Doge.Dock {
    id: dock

    shell: shellApi
    manifest: ({ id: "harryxu.dogedock" })
  }

  QtObject {
    id: shellApi

    property alias appLibrary: library
    property var toggledMenu: []

    function toggle(id, payload) {
      toggledMenu = [id, payload]
      launcher.open()
    }
  }

  QtObject {
    id: library

    property var launched: []
    property var removed: []
    readonly property var entries: [{ id: "editor", name: "Text Editor" }, { id: "browser", name: "Web Browser" }]
    signal appsChanged()

    function sortedEntries(query) {
      return entries.filter(function(entry) {
        return entry.name.toLowerCase().includes(query.toLowerCase())
      }).map(function(entry) { return { entry: entry } })
    }
    function refreshIcons() {}
    function iconSource() { return "" }
    function entryName(entry) { return entry.name }
    function launch(id, name) { launched = [id, name] }
    function remove(id, name) { removed = [id, name] }
  }

  Doge.AppGrid {
    id: launcher

    shell: shellApi
    service: dock
  }

  Doge.DockExtensions {
    id: external

    configured: [
      { path: test.firstPath },
      test.fixture + "/Duplicate",
      test.fixture + "/Incompatible",
      test.fixture + "/Reserved",
      { path: test.secondPath, enabled: false }
    ]
  }

  function findControl(item, propertyName, value) {
    if (item[propertyName] === value && typeof item.clicked === "function") return item
    for (var child of item.children) {
      var match = findControl(child, propertyName, value)
      if (match) return match
    }
    return null
  }

  function expect(condition, message) {
    if (!condition) throw new Error(message)
  }

  function visibleIds(loader) {
    var ids = []
    for (var i = 0; i < loader.model.count; i++) ids.push(loader.model.get(i).extensionId)
    return ids.join(",")
  }

  readonly property var checks: [
    { name: "read and save general Dock settings", run: function() {
      if (!dock.userDockConfig) return false
      expect(dock.position === "left" && !dock.autohide && dock.sizeLevel === 3, "The Dock should apply saved settings and defaults")
      dock.setPosition("right")
      dock.setAutohide(true)
      dock.setSizeLevel(6)
      return true
    }},
    { name: "reconcile queued Dock settings writes", run: function() {
      return dock.position === "right" && dock.autohide && dock.userDockConfig.sizeLevel === 6
    }},
    { name: "center visible icon artwork and ignore faint shadows", run: function() {
      var pixels = new Uint8Array(4 * 4 * 4)
      expect(Geometry.alphaBounds(pixels, 4, 4) === null, "Transparent artwork should have no bounds")
      pixels[3] = 31
      pixels[(1 * 4 + 1) * 4 + 3] = 32
      pixels[(2 * 4 + 1) * 4 + 3] = 255
      var bounds = Geometry.alphaBounds(pixels, 4, 4)
      expect(bounds && bounds.x === 1 && bounds.y === 1 && bounds.width === 1 && bounds.height === 2,
        "Only visible artwork should contribute to the bounds")
      var placement = Geometry.placement(bounds, 4, 20)
      expect(placement.size === 40 && placement.x === -5 && placement.y === -10,
        "The longest side should fill the icon while the artwork is centered")
      return true
    }},
    { name: "search, select and launch through the app grid", run: function() {
      expect(Commons.IpcRegistry.call("omarchy.dock", "apps", []).ran, "The existing apps IPC should be registered")
      expect(shellApi.toggledMenu.join(",") === "harryxu.dogedock,{}" && launcher.opened,
        "The apps IPC should open the DogeDock menu through the shell")
      expect(launcher.apps.length === 2, "Opening the launcher should show both fixture apps")
      launcher.setFilter("browser")
      launcher.select(10)
      expect(launcher.apps.length === 1 && launcher.selectedIndex === 0, "Search should reset and clamp selection")
      launcher.launch(launcher.selectedIndex)
      expect(!launcher.opened && library.launched.join(",") === "browser,Web Browser",
        "Launching should close the grid and send the selected desktop entry to the app library")
      launcher.open()
      expect(launcher.apps.length === 2 && launcher.filterText === "", "Reopening should reset search")
      launcher.requestUninstall(launcher.apps[0])
      launcher.cancelUninstall()
      expect(library.removed.length === 0 && launcher.opened, "Cancelling should leave the app and launcher in place")
      launcher.close()
      return true
    }},
    { name: "load valid extensions and skip invalid or disabled entries", run: function() {
      if (!first || !trash || trash.itemCount !== 0) return false
      expect(visibleIds(external) === "example.first", "Only the first valid external extension should load")
      expect(decodeURIComponent(first.tooltip).includes("/First # extension/"), "The first configured directory should win")
      expect(visibleIds(dock.extensions) === "trash", "Legacy built-in ID should load")
      originalFirst = first
      external.invoke("example.first", "activate", [])
      expect(first.activations === 1, "Activation should reach the extension")
      var actions = external.actionsFor(first)
      expect(actions.length === 1 && actions[0].text === "Reset", "Only valid, unique menu actions should be shown")
      external.invoke("example.first", "triggerAction", [actions[0].id])
      expect(first.activations === 0, "Menu action should reach the extension")
      external.configured = [secondPath, firstPath]
      return true
    }},
    { name: "reorder extensions without recreating them", run: function() {
      if (visibleIds(external) !== "example.second,example.first") return false
      expect(first === originalFirst, "Reorder should preserve the active instance")
      external.configured = [{ path: firstPath, enabled: false }, secondPath]
      var button = findControl(dock.settingsPanel.contentItem, "text", "Extensions")
      if (!button) throw new Error("Missing Extensions navigation button")
      button.clicked()
      return true
    }},
    { name: "disable Trash from the Extensions page", run: function() {
      var toggle = findControl(dock.settingsPanel.contentItem, "label", "Trash")
      if (!toggle || first || visibleIds(external) !== "example.second") return false
      expect(toggle.checked, "The Trash switch should reflect the legacy enabled entry")
      toggle.clicked()
      return true
    }},
    { name: "enable Trash again from the Extensions page", run: function() {
      if (trash || dock.savingExtension) return false
      var toggle = findControl(dock.settingsPanel.contentItem, "label", "Trash")
      expect(!toggle.checked && visibleIds(dock.extensions) === "", "Disabling should remove the Trash icon and clear the switch")
      toggle.clicked()
      return true
    }},
    { name: "offer Open on empty Trash and require confirmation for Empty Trash", run: function() {
      if (!trash || trash.itemCount !== 0 || dock.savingExtension) return false
      var actions = dock.extensions.actionsFor(trash)
      expect(actions[0].id === "open" && actions[0].enabled !== false, "Open should be available on empty Trash")
      expect(actions[1].id === "empty" && actions[1].enabled === false, "Empty Trash should be disabled")
      expect(trash.iconName === "user-trash", "Empty Trash should have its empty icon")
      dock.extensions.invoke("trash", "triggerAction", ["open"])
      dock.extensions.invoke("trash", "triggerAction", ["empty"])
      dock.extensions.invoke("trash", "dropFiles", [[
        "file:///example/keep%20spaces", "file:///example/failed", "file:///example/keep%20spaces"
      ]])
      return true
    }},
    { name: "refresh Trash state after a partially successful drop", run: function() {
      if (trash.itemCount !== 1) return false
      var empty = dock.extensions.actionsFor(trash).find(function(action) { return action.id === "empty" })
      expect(trash.iconName === "user-trash-full", "Nonempty Trash should have its full icon")
      expect(empty.enabled && empty.confirmation && empty.confirmation.message.length > 0, "Empty Trash should request confirmation")
      dock.extensions.invoke("trash", "triggerAction", ["empty"])
      return true
    }},
    { name: "refresh Trash state after emptying", run: function() {
      if (trash.itemCount !== 0) return false
      expect(trash.iconName === "user-trash", "Emptying should restore the empty icon")
      return true
    }}
  ]

  Timer {
    interval: 50
    running: true
    repeat: true
    onTriggered: {
      var check = test.checks[test.step]
      try {
        if (!check.run()) {
          if (++test.attempts >= 80) throw new Error("Timed out")
          return
        }
        console.log("PASS: " + check.name)
        test.attempts = 0
        if (++test.step === test.checks.length) {
          stop()
          console.log("PASS: DogeDock extension integration")
          Qt.quit()
        }
      } catch (error) {
        console.error("FAIL: " + check.name + ": " + error)
        stop()
        Qt.exit(1)
      }
    }
  }
}
