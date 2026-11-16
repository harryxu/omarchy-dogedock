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
  readonly property string multiPath: fixture + "/Multi"
  readonly property var multi: external.instanceFor("example.multi")
  readonly property string firstFolder: fixture + "/First # folder % ready"
  readonly property string secondFolder: fixture + "/Second folder"
  readonly property string missingFolder: fixture + "/Unavailable <folder>"
  readonly property var folders: dock.extensions.instanceFor("folders")
  property var originalFirst: null
  property string projectsKey: ""
  property int step: 0
  property int attempts: 0

  Doge.Dock {
    id: dock

    shell: shellApi
    manifest: ({ id: "harryxu.dogedock" })
  }

  Doge.DockWindow {
    id: extensionWindow

    dock: test.dockService
    screen: Quickshell.screens[0]
  }

  readonly property Item dockService: dock

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

  function findItem(item, matches) {
    if (matches(item)) return item
    for (var child of item.children) {
      var match = findItem(child, matches)
      if (match) return match
    }
    return null
  }

  function findControl(item, propertyName, value) {
    return findItem(item, function(item) { return item[propertyName] === value && typeof item.clicked === "function" })
  }

  function expect(condition, message) {
    if (!condition) throw new Error(message)
  }

  function findNamedObject(item, name) {
    if (item.objectName === name) return item
    for (var child of item.children || []) {
      var match = findNamedObject(child, name)
      if (match) return match
    }
    for (var data of item.data || []) if (data.objectName === name) return data
    return null
  }

  function chooseDirectory(path) {
    var picker = findNamedObject(dock.settingsPanel.contentItem, "extensionDirectoryPicker")
    expect(picker, "The Folders settings should offer a directory picker")
    picker.open()
    picker.selectedFolder = Commons.Util.fileUrl(path)
    picker.accepted()
    picker.close()
  }

  function folderPaths() {
    var paths = []
    for (var i = 0; i < dock.extensions.model.count; i++) {
      var row = dock.extensions.model.get(i)
      if (row.extensionId === "folders") paths.push(dock.extensions.iconFor(row.iconKey).tooltip)
    }
    return paths.join("|")
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
      var iconKey = external.model.get(0).iconKey
      external.invokeIcon(iconKey, "activate", [])
      expect(first.activations === 1, "Activation should reach the extension")
      var actions = external.actionsFor(first)
      expect(actions.length === 1 && actions[0].text === "Reset", "Only valid, unique menu actions should be shown")
      external.invokeIcon(iconKey, "triggerAction", [actions[0].id])
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
      external.configured = [secondPath, { path: multiPath, settings: { names: ["Downloads", 1, "Projects"] } }]
      return true
    }},
    { name: "publish and dispatch multiple icons from one v2 extension", run: function() {
      if (visibleIds(external) !== "example.second,example.multi,example.multi") return false
      var downloads = external.model.get(1).iconKey
      var projects = external.model.get(2).iconKey
      projectsKey = projects
      expect(downloads !== projects && external.iconFor(downloads).tooltip === "Downloads", "Each valid value should supply its own icon")
      expect(external.actionsFor(multi, external.iconFor(projects))[0].id === "open", "The second icon should offer its own actions")
      external.invokeIcon(downloads, "activate", [])
      expect(multi.event.join(",") === "activate,Downloads", "The click should reach Downloads")
      external.invokeIcon(projects, "triggerAction", ["open"])
      expect(multi.event.join(",") === "action,Projects,open", "The menu action should reach Projects")
      external.invokeIcon(projects, "dropFiles", [["file:///example/file"]])
      expect(multi.event.join(",") === "drop,Projects,file:///example/file", "The drop should reach Projects")
      external.configured = [{ path: multiPath, settings: { names: ["Projects", "Downloads"] } }, secondPath]
      return true
    }},
    { name: "retain icon identity on reorder and remove all icons on a live settings update", run: function() {
      if (!multi || multi.settings.names.join(",") !== "Projects,Downloads" || visibleIds(external) !== "example.multi,example.multi,example.second") return false
      var projects = external.model.get(0).iconKey
      expect(projects === projectsKey && external.iconFor(projects).tooltip === "Projects",
        "Projects should keep its identity when moved to the front")
      external.configured = [{ path: multiPath, settings: { names: ["Projects"], show: false } }, secondPath]
      return true
    }},
    { name: "keep a v2 extension active with zero icons", run: function() {
      if (visibleIds(external) !== "example.second") return false
      expect(multi && multi.event.join(",") === "drop,Projects,file:///example/file", "Changing settings should preserve the instance")
      external.invokeIcon(projectsKey, "activate", [])
      expect(multi.event[0] === "drop", "A removed icon should not receive events")
      var toggle = findControl(dock.settingsPanel.contentItem, "label", "Multi Example")
      expect(toggle && !toggle.checked, "The configured external extension should be listed while disabled")
      expect(findItem(dock.settingsPanel.contentItem, function(item) { return item.text === "Error: invalid default for invalid" }),
        "An invalid settings declaration should be reported in the panel")
      expect(!dock.extensions.instanceFor("example.invalid"), "An invalid declaration should prevent the entry point from running")
      toggle.clicked()
      return true
    }},
    { name: "edit external extension settings through the management panel", run: function() {
      var toggle = findControl(dock.settingsPanel.contentItem, "label", "Show icons")
      var instance = dock.extensions.instanceFor("example.multi")
      if (!instance || !toggle || dock.savingExtension) return false
      expect(toggle.checked && visibleIds(dock.extensions) === "trash,example.multi,example.multi",
        "An invalid saved boolean should use the default")
      var slot = findItem(extensionWindow.contentItem, function(item) { return item.iconKey && item.displayName === "Second" })
      expect(slot, "Both extension icons should have their own visible delegates")
      extensionWindow.openExtensionMenu(slot)
      expect(extensionWindow.menuOpen, "The second icon should open its own context menu")
      extensionWindow.chooseExtensionAction("open")
      expect(instance.event.join(",") === "action,Second,open", "The Dock menu should act on its selected icon")
      extensionWindow.openExtensionMenu(slot)
      toggle.clicked()
      return true
    }},
    { name: "edit a numeric setting after its icons are hidden", run: function() {
      if (dock.savingExtension || visibleIds(dock.extensions) !== "trash") return false
      expect(!extensionWindow.menuOpen, "Removing an icon should close its open menu")
      var editor = findItem(dock.settingsPanel.contentItem, function(item) {
        return typeof item.accepted === "function" && item.Accessible.name === "Icon limit"
      })
      expect(editor && editor.text === "5", "The number editor should show its default")
      editor.text = "3oops"
      editor.accepted()
      expect(!dock.savingExtension, "Invalid numeric text should not be saved")
      editor.text = "1.5e1"
      editor.accepted()
      return true
    }},
    { name: "edit a choice defined by the extension", run: function() {
      var instance = dock.extensions.instanceFor("example.multi")
      if (dock.savingExtension || instance.settings.limit !== 15) return false
      var dropdown = findItem(dock.settingsPanel.contentItem, function(item) {
        return item.label === "Palette" && typeof item.changed === "function"
      })
      expect(dropdown && dropdown.value === "warm", "The choice should show its default")
      dropdown.value = "cool"
      dropdown.changed("cool")
      return true
    }},
    { name: "disable an external extension without clearing its parameters", run: function() {
      var instance = dock.extensions.instanceFor("example.multi")
      if (dock.savingExtension || instance.settings.palette !== "cool") return false
      var toggle = findControl(dock.settingsPanel.contentItem, "label", "Multi Example")
      expect(toggle.checked, "An enabled v2 extension can have no icons")
      toggle.clicked()
      return true
    }},
    { name: "unload the external extension after disabling it", run: function() {
      if (dock.savingExtension || dock.extensions.instanceFor("example.multi")) return false
      var toggle = findControl(dock.settingsPanel.contentItem, "label", "Folders")
      expect(toggle && !toggle.checked, "Folders should be available as a built-in")
      dock.settingsPanel.open(Quickshell.screens[0])
      toggle.clicked()
      return true
    }},
    { name: "show no icons for an empty Folders extension and add the first directory", run: function() {
      if (!folders || dock.savingExtension) return false
      expect(visibleIds(dock.extensions) === "trash", "An empty directory list should have no icons")
      chooseDirectory(firstFolder)
      return true
    }},
    { name: "add a second directory with its own icon", run: function() {
      if (folderPaths() !== firstFolder || dock.savingExtension) return false
      chooseDirectory(secondFolder)
      return true
    }},
    { name: "reject a repeated directory and reorder folder icons from the panel", run: function() {
      if (folderPaths() !== [firstFolder, secondFolder].join("|") || dock.savingExtension) return false
      chooseDirectory(secondFolder)
      expect(!dock.savingExtension, "Adding an already configured directory should not write settings")
      var down = findControl(dock.settingsPanel.contentItem, "text", "Down")
      expect(down && down.enabled, "The first directory should be movable down")
      down.clicked()
      return true
    }},
    { name: "open a folder with spaces and reserved URL characters from its reordered icon", run: function() {
      if (folderPaths() !== [secondFolder, firstFolder].join("|") || dock.savingExtension) return false
      dock.extensions.invokeIcon(dock.extensions.model.get(2).iconKey, "activate", [])
      dock.setExtensionSetting("folders", "directories", [missingFolder, secondFolder, firstFolder])
      return true
    }},
    { name: "preserve unavailable directories and let the user remove a folder icon", run: function() {
      if (folderPaths() !== [missingFolder, secondFolder, firstFolder].join("|") || dock.savingExtension) return false
      dock.extensions.invokeIcon(dock.extensions.model.get(1).iconKey, "activate", [])
      var remove = findControl(dock.settingsPanel.contentItem, "text", "Remove")
      expect(remove, "The directory list should offer removal")
      remove.clicked()
      return true
    }},
    { name: "persist the remaining folders in display order", run: function() {
      return !dock.savingExtension && folderPaths() === [secondFolder, firstFolder].join("|")
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
