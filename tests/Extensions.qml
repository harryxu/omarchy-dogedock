import QtQuick
import Quickshell
import Quickshell.Io
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
  readonly property string helloPath: fixture + "/Hello # extension %"
  readonly property var hello: dock.extensions.instanceFor("helloext")
  property var originalHelloView: null
  property var secondDock: null
  property var originalFirst: null
  property string projectsKey: ""
  property int step: 0
  property int attempts: 0

  Doge.Dock {
    id: dock

    shell: shellApi
    manifest: ({ id: "harryxu.dogedock" })
  }

  FileView {
    id: privateFixtureSettings
    path: Quickshell.env("XDG_CONFIG_HOME") + "/harryxu.dogedock/settings.json"
    atomicWrites: true
    printErrors: false
    property var savedSettings

    onLoaded: savedSettings = JSON.parse(text())
  }

  Doge.DockWindow {
    id: extensionWindow

    dock: test.dockService
    screen: Quickshell.screens[0]
  }

  Component {
    id: additionalDock

    Doge.DockWindow {
      dock: test.dockService
      screen: Quickshell.screens[0]
    }
  }

  Doge.DockExtensionIcon {
    id: customRenderer

    width: 32
    height: 32
    icon: null
  }

  Component {
    id: testIcon

    Item {
      required property var icon
      readonly property string value: icon.value
    }
  }

  Component {
    id: invalidIcon

    QtObject { required property var icon }
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
      test.fixture + "/Invalid icons",
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

  function importDirectory(path) {
    var picker = findNamedObject(dock.settingsPanel.contentItem, "externalExtensionPicker")
    expect(picker, "Extensions should offer an external directory picker")
    picker.open()
    picker.selectedFolder = Commons.Util.fileUrl(path)
    picker.accepted()
    picker.close()
  }

  function folderSlot(path) {
    return findItem(extensionWindow.contentItem, function(item) { return item.iconKey && item.displayName === path })
  }

  function folderAction(text) {
    return extensionWindow.anchoredView?.menuActions.find(function(action) { return action.text === text })
  }

  function browseControl(name) {
    return findNamedObject(extensionWindow.contentItem, "extensionBrowse" + name)
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
      if (dock.position !== "left" || !trash || !folders || folderPaths() !== fixture + "/home/Downloads") return false
      expect(!dock.autohide && dock.sizeLevel === 3, "The Dock should apply saved settings and defaults")
      expect(!hello && !dock.extensions.sourceFor(helloPath), "The example must not install automatically")
      expect(dock.extensions.entries.length === 2, "Fresh settings enable Trash and Folders with Downloads")
      dock.setPosition("right")
      dock.setAutohide(true)
      dock.setSizeLevel(6)
      return true
    }},
    { name: "reconcile queued Dock settings writes", run: function() {
      if (dock.position !== "right" || !dock.autohide || dock.sizeLevel !== 6) return false
      if (privateFixtureSettings.savedSettings?.sizeLevel !== 6) {
        privateFixtureSettings.reload()
        return false
      }
      dock.setExtensionEnabled("trash", false)
      return true
    }},
    { name: "save a default extension without losing the other defaults", run: function() {
      if (dock.savingExtension || trash) return false
      expect(folders && folderPaths() === fixture + "/home/Downloads", "Saving Trash must preserve default Folders settings")
      privateFixtureSettings.setText(JSON.stringify({ sizeLevel: 6, extensions: [] }))
      return true
    }},
    { name: "respect an explicitly empty extension list", run: function() {
      if (dock.extensions.entries.length !== 0 || trash || folders) return false
      privateFixtureSettings.setText(JSON.stringify({
        sizeLevel: 6,
        future: "preserve this",
        extensions: JSON.parse(Quickshell.env("DOGEDOCK_TEST_EXTENSIONS"))
      }))
      return true
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
      var invalid = external.sourceFor(fixture + "/Invalid icons")
      if (!invalid || !invalid.error) return false
      expect(invalid.error.includes("icons"), "A declared icons property must contain an array")
      expect(visibleIds(external) === "example.first", "Only the first valid external extension should load")
      expect(decodeURIComponent(first.tooltip).includes("/First # extension/"), "The first configured directory should win")
      expect(visibleIds(dock.extensions) === "trash", "Legacy built-in ID should load")
      originalFirst = first
      var iconKey = external.model.get(0).iconKey
      external.invokeIcon(iconKey, "activate", [])
      expect(first.activations === 1, "Activation should reach the extension")
      var actions = external.actionsFor(first, external.iconFor(iconKey))
      expect(actions.length === 1 && actions[0].text === "Reset", "Only valid, unique menu actions should be shown")
      external.invokeIcon(iconKey, "triggerAction", [actions[0].id])
      expect(first.activations === 0, "Menu action should reach the extension")
      external.configured = [secondPath, firstPath]
      return true
    }},
    { name: "publish multiple icons without settings and keep instances across reorder", run: function() {
      if (visibleIds(external) !== "example.second,example.second,example.first") return false
      expect(first === originalFirst, "Reorder should preserve the active instance")
      var secondIcon = external.model.get(1).iconKey
      external.invokeIcon(secondIcon, "activate", [])
      expect(external.instanceFor("example.second").activated === "second",
        "The icons array should select icon-aware callbacks without a settings declaration")
      external.configured = [{ path: firstPath, enabled: false }, secondPath]
      var button = findControl(dock.settingsPanel.contentItem, "text", "Extensions")
      if (!button) throw new Error("Missing Extensions navigation button")
      button.clicked()
      return true
    }},
    { name: "disable Trash from the Extensions page", run: function() {
      var toggle = findControl(dock.settingsPanel.contentItem, "label", "Trash")
      if (!toggle || first || visibleIds(external) !== "example.second,example.second") return false
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
      var key = dock.extensions.model.get(0).iconKey
      var icon = dock.extensions.iconFor(key)
      var actions = dock.extensions.actionsFor(trash, icon)
      expect(actions[0].id === "open" && actions[0].enabled !== false, "Open should be available on empty Trash")
      expect(actions[1].id === "empty" && actions[1].enabled === false, "Empty Trash should be disabled")
      expect(icon.iconName === "user-trash", "Empty Trash should have its empty icon")
      dock.extensions.invokeIcon(key, "triggerAction", ["open"])
      dock.extensions.invokeIcon(key, "triggerAction", ["empty"])
      dock.extensions.invokeIcon(key, "dropFiles", [[
        "file:///example/keep%20spaces", "file:///example/failed", "file:///example/keep%20spaces"
      ]])
      return true
    }},
    { name: "refresh Trash state after a partially successful drop", run: function() {
      if (trash.itemCount !== 1) return false
      var key = dock.extensions.model.get(0).iconKey
      var icon = dock.extensions.iconFor(key)
      var empty = dock.extensions.actionsFor(trash, icon).find(function(action) { return action.id === "empty" })
      expect(icon.iconName === "user-trash-full", "Nonempty Trash should have its full icon")
      expect(empty.enabled && empty.confirmation && empty.confirmation.message.length > 0, "Empty Trash should request confirmation")
      dock.extensions.invokeIcon(key, "triggerAction", ["empty"])
      return true
    }},
    { name: "refresh Trash state after emptying", run: function() {
      if (trash.itemCount !== 0) return false
      expect(dock.extensions.iconFor(dock.extensions.model.get(0).iconKey).iconName === "user-trash",
        "Emptying should restore the empty icon")
      external.configured = [secondPath, { path: multiPath, settings: { names: ["Downloads", 1, "Projects"] } }]
      return true
    }},
    { name: "publish and dispatch multiple icons from manifest settings", run: function() {
      if (visibleIds(external) !== "example.second,example.second,example.multi,example.multi") return false
      var downloads = external.model.get(2).iconKey
      var projects = external.model.get(3).iconKey
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
      if (!multi || multi.settings.names.join(",") !== "Projects,Downloads"
        || visibleIds(external) !== "example.multi,example.multi,example.second,example.second") return false
      var projects = external.model.get(0).iconKey
      expect(projects === projectsKey && external.iconFor(projects).tooltip === "Projects",
        "Projects should keep its identity when moved to the front")
      external.configured = [{ path: multiPath, settings: { names: ["Projects"] } }, secondPath]
      return true
    }},
    { name: "keep the same callback interface when a configurable extension shows one icon", run: function() {
      if (visibleIds(external) !== "example.multi,example.second,example.second") return false
      expect(multi && multi.event.join(",") === "drop,Projects,file:///example/file", "Changing settings should preserve the instance")
      expect(external.model.get(0).iconKey === projectsKey, "The remaining icon should retain its identity")
      external.invokeIcon(projectsKey, "activate", [])
      expect(multi.event.join(",") === "activate,Projects", "A one-item array still passes the icon ID")
      external.configured = [{ path: multiPath, settings: { names: ["Projects"], show: false } }, secondPath]
      return true
    }},
    { name: "keep a configurable extension active with zero icons", run: function() {
      if (visibleIds(external) !== "example.second,example.second") return false
      expect(multi && multi.event.join(",") === "activate,Projects", "An empty array should preserve the instance")
      external.invokeIcon(projectsKey, "triggerAction", ["open"])
      expect(multi.event.join(",") === "activate,Projects", "A removed icon should not receive events")
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
      expect(toggle.checked, "An enabled extension can have no icons")
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
    { name: "route file drops to the folder represented by the icon", run: function() {
      if (folderPaths() !== [secondFolder, firstFolder].join("|") || dock.savingExtension) return false
      var slot = folderSlot(firstFolder)
      expect(slot && slot.dropExtensionKey, "Folder icons should accept file drops")
      dock.extensions.invokeIcon(slot.dropExtensionKey, "dropFiles", [[
        Commons.Util.fileUrl(fixture + "/Folder alias/top-level.txt"),
        Commons.Util.fileUrl(fixture + "/top-level.txt"),
        Commons.Util.fileUrl(fixture + "/copy # 100%.txt"),
        Commons.Util.fileUrl(fixture + "/copy # 100%.txt")
      ]])
      return true
    }},
    { name: "show a folder menu with a top action, subdirectories and files", run: function() {
      if (folderPaths() !== [secondFolder, firstFolder].join("|") || dock.savingExtension) return false
      extensionWindow.activateExtension(folderSlot(firstFolder))
      expect(extensionWindow.menuOpen, "Left click should open the folder menu")
      expect(!findNamedObject(extensionWindow.contentItem, "dockActionMenu").visible,
        "An anchored view should not show the Dock action menu")
      expect(extensionWindow.anchoredView.menuActions[0].text === "Open Current Folder", "Open Current Folder belongs at the top")
      extensionWindow.activateExtension(folderSlot(firstFolder))
      expect(!extensionWindow.menuOpen, "Clicking the same folder again should close its menu")
      extensionWindow.activateExtension(folderSlot(firstFolder))
      expect(extensionWindow.menuOpen, "Clicking again should reopen the folder menu")
      extensionWindow.handleOutsideClick()
      expect(!extensionWindow.menuOpen, "Folders should close its view when the host forwards an outside click")
      extensionWindow.activateExtension(folderSlot(firstFolder))
      return true
    }},
    { name: "replace the menu contents when entering a subdirectory", run: function() {
      var nested = folderAction("Nested # folder")
      if (!nested) return false
      expect(!browseControl("ScrollUp").visible && !browseControl("ScrollDown").visible,
        "A short list should show neither scroll indicator")
      expect(folderAction("top-level.txt"), "The root file should be present")
      extensionWindow.anchoredView.activateAction(nested.id)
      expect(extensionWindow.menuOpen, "Entering a subdirectory should keep the menu open")
      return true
    }},
    { name: "open a file from the subdirectory menu", run: function() {
      var file = folderAction("notes %20.txt")
      if (!file) return false
      expect(!folderAction("top-level.txt"), "The submenu should replace the parent contents")
      extensionWindow.anchoredView.activateAction(file.id)
      expect(!extensionWindow.menuOpen, "Opening a file should close the menu")
      extensionWindow.activateExtension(folderSlot(firstFolder))
      return true
    }},
    { name: "browse into the subdirectory again", run: function() {
      var nested = folderAction("Nested # folder")
      if (!nested) return false
      extensionWindow.anchoredView.activateAction(nested.id)
      return true
    }},
    { name: "return to the parent folder in the same menu", run: function() {
      if (!folderAction("notes %20.txt")) return false
      extensionWindow.anchoredView.activateAction(folderAction("Back").id)
      expect(extensionWindow.menuOpen, "Back should keep the menu open")
      return true
    }},
    { name: "enter a child again from the restored parent contents", run: function() {
      var nested = folderAction("Nested # folder")
      if (!nested) return false
      expect(!folderAction("Back") && !folderAction("notes %20.txt"), "The root menu should restore just the root contents")
      extensionWindow.anchoredView.activateAction(nested.id)
      return true
    }},
    { name: "open the current subdirectory and use the context menu to open the configured root", run: function() {
      if (!folderAction("notes %20.txt")) return false
      extensionWindow.anchoredView.activateAction(extensionWindow.anchoredView.menuActions[0].id)
      expect(!extensionWindow.menuOpen, "Opening the current folder should close the menu")
      extensionWindow.openExtensionMenu(folderSlot(firstFolder))
      expect(extensionWindow.anchoredView.menuActions.length === 1 && extensionWindow.anchoredView.menuActions[0].text === "Open",
        "The right-click menu should have one Open action")
      extensionWindow.anchoredView.activateAction(extensionWindow.anchoredView.menuActions[0].id)
      dock.setExtensionSetting("folders", "directories", [missingFolder, secondFolder, firstFolder])
      return true
    }},
    { name: "open the browser for an unavailable folder", run: function() {
      if (folderPaths() !== [missingFolder, secondFolder, firstFolder].join("|") || dock.savingExtension) return false
      extensionWindow.activateExtension(folderSlot(missingFolder))
      return true
    }},
    { name: "show a read error and preserve the unavailable folder until removed", run: function() {
      var error = folderAction("Could not read this folder.")
      if (!error) return false
      expect(error.enabled === false && extensionWindow.anchoredView.menuActions[0].id === "open", "Keep Open visible during listing errors")
      extensionWindow.openExtensionMenu(folderSlot(missingFolder))
      extensionWindow.anchoredView.activateAction("open")
      var field = findItem(dock.settingsPanel.contentItem, function(item) { return item.field && item.field.key === "directories" && typeof item.removeItem === "function" })
      var remove = findControl(field, "text", "Remove")
      expect(remove, "The directory list should offer removal")
      remove.clicked()
      return true
    }},
    { name: "persist the remaining folders in display order", run: function() {
      if (dock.savingExtension || folderPaths() !== [secondFolder, firstFolder].join("|")) return false
      dock.setPosition("bottom")
      return true
    }},
    { name: "open a long folder list on a horizontal dock", run: function() {
      if (extensionWindow.position !== "bottom") return false
      extensionWindow.activateExtension(folderSlot(secondFolder))
      return true
    }},
    { name: "show more than six rows and hint when there is content below", run: function() {
      var viewport = browseControl("Viewport")
      if (viewport.count !== 60) return false
      expect(viewport.height > extensionWindow.popupRoom, "A long list should have more height than a standard menu")
      expect(!browseControl("ScrollUp").visible && browseControl("ScrollDown").visible,
        "Only the down indicator should appear at the top")
      var start = viewport.contentY
      browseControl("ScrollDown").scroll()
      expect(viewport.contentY > start, "The down control should move the list down")
      return true
    }},
    { name: "show both scroll indicators in the middle of the folder", run: function() {
      expect(browseControl("ScrollUp").visible && browseControl("ScrollDown").visible,
        "Both indicators should appear when there is content above and below")
      var viewport = browseControl("Viewport")
      var start = viewport.contentY
      browseControl("ScrollUp").scroll()
      expect(viewport.atYBeginning && viewport.contentY < start, "The up control should move back to the top")
      var down = browseControl("ScrollDown")
      var pointer = findItem(down, function(item) { return typeof item.pressAndHold === "function" })
      pointer.pressAndHold(null)
      return true
    }},
    { name: "repeat scrolling while an indicator is held", run: function() {
      var viewport = browseControl("Viewport")
      if (viewport.atYBeginning) return false
      var down = browseControl("ScrollDown")
      var pointer = findItem(down, function(item) { return typeof item.pressAndHold === "function" })
      pointer.released(null)
      expect(!down.held, "Releasing the indicator should stop the repeat timer")
      for (var i = 0; i < viewport.count; i++) browseControl("ScrollDown").scroll()
      return true
    }},
    { name: "show only the up indicator at the bottom of the folder", run: function() {
      expect(browseControl("ScrollUp").visible && !browseControl("ScrollDown").visible,
        "Only the up indicator should appear at the bottom")
      extensionWindow.closeMenu()
      dock.setPosition("right")
      return true
    }},
    { name: "restore the original test dock position", run: function() {
      if (extensionWindow.position !== "right") return false
      external.configured = [{ path: fixture + "/Empty settings", settings: { unknown: true } }]
      return true
    }},
    { name: "supply an empty settings object for an explicit empty declaration", run: function() {
      return visibleIds(external) === "example.empty-settings"
    }},
    { name: "mount a custom icon component with its data", run: function() {
      customRenderer.icon = { iconComponent: testIcon, value: "First" }
      expect(customRenderer.view && customRenderer.view.value === "First", "Required icon data must be supplied at creation")
      originalHelloView = customRenderer.view
      customRenderer.icon = { iconComponent: testIcon, value: "Updated" }
      customRenderer.width = 48
      return true
    }},
    { name: "update custom icon data and size without recreating its view", run: function() {
      expect(customRenderer.view === originalHelloView && customRenderer.view.value === "Updated",
        "The same component must retain its view and receive reactive icon data")
      expect(customRenderer.view.width === 48 && customRenderer.view.height === 32, "View size follows its host")
      customRenderer.icon = { iconComponent: invalidIcon }
      expect(!customRenderer.view, "A nonvisual component must not be mounted")
      customRenderer.icon = { iconComponent: "not a component" }
      expect(!customRenderer.view, "An invalid component reference must not be mounted")
      customRenderer.icon = null
      originalHelloView = null
      return true
    }},
    { name: "reject a directory without a manifest", run: function() {
      importDirectory(firstFolder)
      return true
    }},
    { name: "reject malformed JSON", run: function() {
      if (dock.savingExtension || !dock.extensionSaveError) return false
      expect(!dock.extensions.sourceFor(firstFolder), "Invalid imports must not be saved")
      importDirectory(fixture + "/Bad JSON")
      return true
    }},
    { name: "reject a missing QML entry point", run: function() {
      if (dock.savingExtension || !dock.extensionSaveError) return false
      importDirectory(fixture + "/Missing entry")
      return true
    }},
    { name: "reject entry point traversal", run: function() {
      if (dock.savingExtension || !dock.extensionSaveError) return false
      importDirectory(fixture + "/Traversal")
      return true
    }},
    { name: "reject reserved IDs", run: function() {
      if (dock.savingExtension || !dock.extensionSaveError) return false
      importDirectory(fixture + "/Reserved")
      return true
    }},
    { name: "finish rejecting invalid manifests", run: function() {
      if (dock.savingExtension || !dock.extensionSaveError) return false
      importDirectory(fixture + "/Bad settings import")
      return true
    }},
    { name: "reject invalid settings before adding the hello example", run: function() {
      if (dock.savingExtension || !dock.extensionSaveError) return false
      expect(!dock.extensions.sourceFor(fixture + "/Bad settings import"), "Invalid settings must not be imported")
      importDirectory(helloPath)
      return true
    }},
    { name: "import and enable the uninstalled hello example", run: function() {
      if (dock.savingExtension || !hello) return false
      expect(!dock.extensionSaveError && hello.icons.length === 0, "A valid import starts with default settings")
      expect(dock.extensions.settingsSources.some(function(source) { return source.reference === helloPath }),
        "External extensions belong in the same settings list")
      importDirectory(helloPath + "/")
      return true
    }},
    { name: "reject the same directory twice", run: function() {
      if (dock.savingExtension || !dock.extensionSaveError) return false
      expect(dock.extensions.entries.filter(function(entry) { return entry.reference === helloPath }).length === 1,
        "Import must not duplicate the path")
      importDirectory(fixture + "/Duplicate hello")
      return true
    }},
    { name: "reject a duplicate ID even from another directory", run: function() {
      if (dock.savingExtension || !dock.extensionSaveError) return false
      expect(!dock.extensions.sourceFor(fixture + "/Duplicate hello"), "Duplicate IDs must not be saved")
      dock.setExtensionSetting(helloPath, "names", ["Alice", "张三", "Alice", "<img>", "😀 Smile", "  "])
      return true
    }},
    { name: "render a text icon for each nonblank name", run: function() {
      if (dock.savingExtension || hello.icons.length !== 5) return false
      expect(hello.icons.every(function(icon) { return icon.iconComponent instanceof Component }),
        "The extension supplies its own rendering component")
      var initials = hello.icons.map(function(icon) {
        var slot = findItem(extensionWindow.contentItem, function(item) { return item.iconKey === JSON.stringify(["helloext", icon.id]) })
        var initial = slot && findNamedObject(slot, "helloInitial")
        return initial ? initial.text : "missing"
      })
      expect(initials.join("|") === "A|张|A|<|😀", "Extension-rendered icons use the first Unicode character")
      expect(new Set(hello.icons.map(function(icon) { return icon.id })).size === 5, "Duplicate names need distinct icon IDs")
      var slot = findItem(extensionWindow.contentItem, function(item) { return item.iconKey && item.displayName === "<img>" })
      var host = slot && findNamedObject(slot, "dockExtensionIcon")
      expect(host && host.view && host.view.width === extensionWindow.iconSize && host.view.height === extensionWindow.iconSize,
        "The Dock sizes the extension-owned visual")
      expect(!host.enabled && host.clip && slot.mouse.cursorShape === Qt.ArrowCursor,
        "The Dock retains pointer handling and clips custom visuals to the icon area")
      extensionWindow.activateExtension(slot)
      return true
    }},
    { name: "show a plain text greeting and close it", run: function() {
      var greeting = findNamedObject(extensionWindow.contentItem, "helloGreeting")
      if (!greeting) return false
      expect(greeting.text === "Hello <img>" && greeting.textFormat === Text.PlainText, "Names must stay plain text")
      var close = findControl(extensionWindow.contentItem, "text", "Close")
      expect(close, "The greeting needs a close button")
      close.clicked()
      expect(!extensionWindow.anchoredView, "Close should dismiss the greeting")
      var slot = findItem(extensionWindow.contentItem, function(item) { return item.iconKey && item.displayName === "<img>" })
      originalHelloView = findNamedObject(slot, "dockExtensionIcon").view
      secondDock = additionalDock.createObject(test)
      dock.setExtensionSetting(helloPath, "names", ["😀 Smile", "<img>", "Alice", "张三", "Alice", "  "])
      return true
    }},
    { name: "preserve custom visuals on reorder and create separate visuals for each Dock", run: function() {
      if (dock.savingExtension || hello.icons[0].tooltip !== "😀 Smile") return false
      var slot = findItem(extensionWindow.contentItem, function(item) { return item.iconKey && item.displayName === "<img>" })
      var other = findItem(secondDock.contentItem, function(item) { return item.iconKey === slot.iconKey })
      if (!other) return false
      var view = findNamedObject(slot, "dockExtensionIcon").view
      var otherView = findNamedObject(other, "dockExtensionIcon").view
      expect(view === originalHelloView, "Reordering should preserve a custom visual with the same icon ID")
      expect(otherView && otherView !== view && otherView.icon === view.icon,
        "Each Dock creates its own visual from shared extension data")
      secondDock.destroy()
      secondDock = null
      originalHelloView = null
      dock.setExtensionEnabled(helloPath, false)
      return true
    }},
    { name: "disable an external extension and retain its names", run: function() {
      if (dock.savingExtension || hello) return false
      expect(!findNamedObject(extensionWindow.contentItem, "helloInitial"), "Disabling must destroy the extension's visual instances")
      expect(dock.extensions.sourceFor(helloPath).resolved.values.names.length === 6, "Disabling must retain settings")
      dock.setExtensionEnabled(helloPath, true)
      return true
    }},
    { name: "restore the example and remove it through its settings control", run: function() {
      if (dock.savingExtension || !hello || hello.icons.length !== 5) return false
      var toggle = findControl(dock.settingsPanel.contentItem, "label", "Hello Extension")
      expect(toggle, "The external extension must have a standard enable switch")
      var remove = toggle.parent.children.find(function(item) { return item.text === "Remove" })
      expect(remove && remove.visible, "External extensions must offer Remove")
      remove.clicked()
      return true
    }},
    { name: "unload and forget the removed extension", run: function() {
      if (dock.savingExtension || hello || dock.extensions.sourceFor(helloPath)) return false
      expect(!dock.extensions.entries.some(function(entry) { return entry.reference === helloPath }),
        "Removal must drop the saved entry and its settings")
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
