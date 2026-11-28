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
  readonly property var wallpaper: dock.extensions.instanceFor("wallpaper")
  readonly property string wallpaperDirectory: fixture + "/Pictures # 100%"
  readonly property string firstImage: wallpaperDirectory + "/A # first.png"
  readonly property string secondImage: wallpaperDirectory + "/B % second.PNG"
  readonly property string thirdImage: wallpaperDirectory + "/C third.png"
  readonly property string menuImage: fixture + "/Menu # image.png"
  readonly property string droppedImage: fixture + "/Drop # image.png"
  readonly property string menuDirectory: fixture + "/Menu # directory"
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

  component AppWindow: QtObject {
    readonly property string appId: "dogedock-test-text"
    property string title
    property int activations: 0

    function activate() { activations += 1 }
  }

  AppWindow { id: firstWindow; title: "Notes <draft>" }
  AppWindow { id: secondWindow; title: "Checklist" }

  FileView {
    id: privateFixtureSettings
    path: Quickshell.env("XDG_CONFIG_HOME") + "/harryxu.dogedock/settings.json"
    atomicWrites: true
    printErrors: false
    property var savedSettings

    onLoaded: savedSettings = JSON.parse(text())
  }

  FileView {
    id: shellFixtureSettings
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
  }

  Window {
    width: 1280
    height: 800
    visible: true

    Doge.DockWindow {
      id: extensionWindow

      dock: test.dockService
      screen: Quickshell.screens[0]
    }
  }

  Doge.DockFileDrop {
    id: fileDrop

    appIds: ["dogedock-test-text", "missing"]
    slotAt: function() { return null }
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

  function findAction(item, accessibleName) {
    return findItem(item, function(item) {
      return item.Accessible && item.Accessible.name === accessibleName && typeof item.clicked === "function"
    })
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

  function trashSlot() {
    return findItem(extensionWindow.contentItem, function(item) { return item.iconKey && item.extensionId === "trash" })
  }

  function wallpaperSlot() {
    return findItem(extensionWindow.contentItem, function(item) { return item.iconKey && item.extensionId === "wallpaper" })
  }

  function dropOnWallpaper(paths) {
    var slot = wallpaperSlot()
    expect(slot && slot.dropExtensionKey === slot.iconKey, "The Wallpaper icon should accept file drops")
    var area = findItem(extensionWindow.contentItem, function(item) { return typeof item.filesDropped === "function" })
    area.filesDropped(slot, paths.map(Commons.Util.fileUrl))
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
      expect(extensionWindow.edgeInset === Commons.Style.spacing.md, "Changing the Dock size must preserve its screen edge inset")
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
    { name: "list app windows above actions and activate the selected window", run: function() {
      var appId = firstWindow.appId
      dock.testToplevels = [
        { wayland: firstWindow, workspace: { id: 1 } },
        { wayland: secondWindow, workspace: { id: 2 } },
      ]
      var slot = findItem(extensionWindow.contentItem, function(item) { return item.appId === appId })
      expect(slot, "The running app should have a Dock slot")
      extensionWindow.openMenu(dock.itemFor(appId), slot)
      var menu = findNamedObject(extensionWindow.contentItem, "dockActionMenu")
      var firstRow = findItem(menu, function(item) { return item.text === firstWindow.title && typeof item.triggered === "function" })
      var secondRow = findItem(menu, function(item) { return item.text === secondWindow.title && typeof item.triggered === "function" })
      expect(menu.visible && firstRow && secondRow, "The menu should show titles from both workspaces")
      var rows = firstRow.parent.children.filter(function(item) { return item.visible && typeof item.triggered === "function" })
      expect(rows[0] === firstRow && rows[1] === secondRow && rows.length > 2, "Window rows should precede app actions")
      secondWindow.title = firstWindow.title
      expect(secondRow.text === firstWindow.title, "An open menu should follow window title changes")
      secondRow.children.find(function(item) { return typeof item.clicked === "function" }).clicked(null)
      expect(!extensionWindow.menuOpen && firstWindow.activations === 0 && secondWindow.activations === 1,
        "Choosing a row should close the menu and activate its window, even with duplicate titles")
      extensionWindow.openMenu(dock.itemFor(appId), slot)
      dock.testToplevels = dock.testToplevels.slice(1)
      expect(menu.item.windows.length === 1 && menu.item.windows[0].toplevel === secondWindow,
        "Closed windows should leave the open menu")
      dock.testToplevels = []
      expect(!extensionWindow.menuOpen, "The menu should close when the unpinned app leaves the Dock")
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
    { name: "offer Open and disable Empty Trash when there are no items", run: function() {
      if (!trash || trash.itemCount !== 0 || dock.savingExtension) return false
      var key = dock.extensions.model.get(0).iconKey
      var icon = dock.extensions.iconFor(key)
      var slot = trashSlot()
      if (!slot) return false
      extensionWindow.openExtensionMenu(slot)
      var open = findControl(extensionWindow.anchoredView, "text", "Open")
      var empty = findControl(extensionWindow.anchoredView, "text", "Empty Trash…")
      expect(open.enabled, "Open should be available on empty Trash")
      expect(!empty.enabled, "Empty Trash should be disabled")
      expect(icon.iconName === "user-trash", "Empty Trash should have its empty icon")
      empty.clicked()
      expect(!trash.confirmation.visible, "Disabled Empty Trash should not show a confirmation")
      open.clicked()
      dock.extensions.invokeIcon(key, "dropFiles", [[
        "file:///example/keep%20spaces", "file:///example/failed", "file:///example/keep%20spaces"
      ]])
      return true
    }},
    { name: "open the compact Trash confirmation and cancel it", run: function() {
      if (!trash.canEmpty) return false
      expect(trash.icons[0].iconName === "user-trash-full", "Nonempty Trash should have its full icon")
      extensionWindow.openExtensionMenu(trashSlot())
      var empty = findControl(extensionWindow.anchoredView, "text", "Empty Trash…")
      expect(empty.enabled, "Empty Trash should be enabled after the drop")
      empty.clicked()
      var confirmation = trash.confirmation
      expect(!extensionWindow.anchoredView && confirmation.visible && confirmation.screen === extensionWindow.screen,
        "The extension should replace its menu with a dialog on the same screen")
      expect(confirmation.implicitWidth < confirmation.screen.width && confirmation.implicitHeight < confirmation.screen.height,
        "The confirmation surface should be smaller than the screen")
      findControl(confirmation.contentItem, "text", "Cancel").clicked()
      expect(!confirmation.visible && trash.canEmpty, "Cancel should close the confirmation without starting an operation")
      return true
    }},
    { name: "empty Trash only after accepting the extension dialog", run: function() {
      expect(trash.canEmpty && trash.itemCount === 1, "Cancel should leave the item in the Trash")
      extensionWindow.openExtensionMenu(trashSlot())
      findControl(extensionWindow.anchoredView, "text", "Empty Trash…").clicked()
      expect(trash.confirmation.visible, "Empty Trash should request confirmation again")
      findControl(trash.confirmation.contentItem, "text", "Empty Trash").clicked()
      expect(!trash.confirmation.visible, "Accepting should close the confirmation")
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
      expect(extensionWindow.extensionActions.length === 1, "Actions that relied on host confirmation should be hidden")
      var previousEvent = instance.event
      extensionWindow.chooseExtensionAction("discard")
      expect(instance.event === previousEvent, "An action that relied on host confirmation must never be dispatched")
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
      var remove = findAction(toggle, "Remove Hello Extension")
      expect(remove && remove.visible, "External extensions must offer Remove")
      remove.clicked()
      return true
    }},
    { name: "unload and forget the removed extension", run: function() {
      if (dock.savingExtension || hello || dock.extensions.sourceFor(helloPath)) return false
      expect(!dock.extensions.entries.some(function(entry) { return entry.reference === helloPath }),
        "Removal must drop the saved entry and its settings")
      return true
    }},
    { name: "look up and pin app IDs matching object properties", run: function() {
      expect(dock.itemFor("constructor") === null, "A missing app ID must return null")
      dock.pinAt("__proto__", 0)
      expect(dock.pinnedKeys.join(",") === "__proto__,example", "Pinning must retain the new ID and the hidden pin")
      return true
    }},
    { name: "save the updated pins to Shell settings", run: function() {
      return JSON.parse(shellFixtureSettings.text()).dock.pinned.join(",") === "__proto__,example"
    }},
    { name: "start the app drop check without exposing drag data in process arguments", run: function() {
      fileDrop.startAppDropCheck([Commons.Util.fileUrl(fixture + "/résumé # notes.txt")])
      expect(fileDrop.check.command.length === 2, "The helper command must contain only the interpreter and script")
      return true
    }},
    { name: "read compatible apps and canonical URIs from the probe", run: function() {
      if (!fileDrop.result) return false
      expect(fileDrop.result.appIds.join(",") === "dogedock-test-text", "Only the compatible app should match")
      expect(decodeURIComponent(fileDrop.result.uris.join(",")) === "file://" + fixture + "/résumé # notes.txt",
        "The probe must return the complete file URI")
      fileDrop.reset()
      return true
    }},
    { name: "enable the built-in wallpaper extension from its disabled list row", run: function() {
      var content = dock.settingsPanel.contentItem
      var toggle = findControl(content, "label", "Wallpaper")
      expect(toggle && !toggle.checked && !wallpaper, "Wallpaper should be opt-in")
      expect(!findControl(content, "text", "Wallpaper"), "Disabled extensions should have no sidebar entry")
      var settings = findAction(toggle, "Settings for Wallpaper")
      expect(settings && !settings.enabled, "The list jump should be available when enabled")
      toggle.clicked()
      return true
    }},
    { name: "navigate to the extension-owned page and apply a single image", run: function() {
      if (!wallpaper || !wallpaper.ready || dock.savingExtension) return false
      var content = dock.settingsPanel.contentItem
      expect(findControl(content, "text", "Wallpaper"), "Enabled extensions should have a sidebar entry")
      var settings = findAction(findControl(content, "label", "Wallpaper"), "Settings for Wallpaper")
      settings.clicked()
      var page = findItem(content, function(item) { return item.wallpaper === wallpaper })
      expect(page, "The settings button should load a page bound to the running extension")
      var picker = findNamedObject(content, "wallpaperImagePicker")
      expect(picker && page.pathFromUrl(Commons.Util.fileUrl(secondImage)) === secondImage,
        "The picker should preserve special characters in a local path")
      page.image = secondImage
      findControl(content, "text", "Apply").clicked()
      return true
    }},
    { name: "enable the optional wallpaper icon without reapplying the image", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === secondImage && !wallpaper.rotation.running, "Single mode should apply once")
      var toggle = findNamedObject(dock.settingsPanel.contentItem, "wallpaperDockIconSwitch")
      expect(toggle && !toggle.checked && !wallpaperSlot(), "Wallpaper should default to no Dock icon")
      toggle.toggled()
      return true
    }},
    { name: "open the same single-image menu with either mouse button", run: function() {
      if (wallpaper.busy || !wallpaperSlot()) return false
      extensionWindow.activateExtension(wallpaperSlot())
      var left = extensionWindow.anchoredView.menuActions.map(function(action) { return action.id }).join(",")
      extensionWindow.closeMenu()
      extensionWindow.openExtensionMenu(wallpaperSlot())
      var right = extensionWindow.anchoredView.menuActions.map(function(action) { return action.id }).join(",")
      expect(left === "image,export,settings" && right === left, "Both clicks should open the same single-image menu")
      dock.settingsPanel.close()
      dock.settingsPanel.selectedKey = "general"
      extensionWindow.anchoredView.activateAction("settings")
      expect(dock.settingsPanel.visible && dock.settingsPanel.selectedKey === "extension:wallpaper" && !extensionWindow.anchoredView,
        "The menu Settings action should open the Wallpaper page and close the menu")
      extensionWindow.openExtensionMenu(wallpaperSlot())
      extensionWindow.anchoredView.activateAction("image")
      var picker = findNamedObject(extensionWindow.anchoredView, "wallpaperMenuImagePicker")
      expect(picker && picker.visible, "Change wallpaper should show the image picker")
      picker.selectedFile = Commons.Util.fileUrl(menuImage)
      picker.accepted()
      return true
    }},
    { name: "drop the first supported image onto the single wallpaper icon", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === menuImage, "The Dock picker should apply the selected image")
      dropOnWallpaper([wallpaperDirectory + "/0 fake.png", droppedImage, firstImage])
      return true
    }},
    { name: "open Wallpaper from the sidebar and start rotation with the first image", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === droppedImage && wallpaper.config.image === droppedImage && !wallpaper.rotation.running,
        "The first supported dropped file should become the saved single image")
      var content = dock.settingsPanel.contentItem
      findControl(content, "text", "Extensions").clicked()
      expect(!findNamedObject(content, "wallpaperImagePicker"), "Leaving a page should unload its view")
      findControl(content, "text", "Wallpaper").clicked()
      var page = findItem(content, function(item) { return item.wallpaper === wallpaper })
      expect(page && page.image === droppedImage, "The settings page should show the saved single image")
      findControl(content, "text", "Directory rotation").clicked()
      page.directory = wallpaperDirectory
      expect(!findControl(content, "text", "Previous").enabled && !findControl(content, "text", "Next").enabled,
        "Navigation should wait until the selected directory is applied")
      findControl(content, "text", "Apply").clicked()
      return true
    }},
    { name: "step backward from the first image and pause the timer during the switch", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === firstImage && wallpaper.rotation.running, "Directory mode should apply the first image and start the timer")
      var previous = findControl(dock.settingsPanel.contentItem, "text", "Previous")
      expect(previous.enabled, "Previous should be available for the applied directory")
      previous.clicked()
      expect(wallpaper.busy && !wallpaper.rotation.running, "A manual switch should stop the pending countdown")
      return true
    }},
    { name: "step forward from the last image after the timer restarts", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === thirdImage && wallpaper.rotation.running, "Previous should wrap to the last image and restart the timer")
      findControl(dock.settingsPanel.contentItem, "text", "Next").clicked()
      expect(wallpaper.busy && !wallpaper.rotation.running, "Next should also stop the pending countdown")
      return true
    }},
    { name: "rotate while the settings window is closed", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === firstImage && wallpaper.rotation.running, "Next should wrap to the first image and restart the timer")
      dock.settingsPanel.close()
      expect(!findNamedObject(dock.settingsPanel.contentItem, "wallpaperDirectoryPicker"), "Closing settings should unload the view")
      wallpaper.rotation.triggered()
      return true
    }},
    { name: "disable rotation and return to the Extensions page", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === secondImage, "The next timer tick should use the next image")
      dock.settingsPanel.open(Quickshell.screens[0])
      dock.setExtensionEnabled("wallpaper", false)
      return true
    }},
    { name: "remove the disabled extension's page and sidebar item", run: function() {
      if (wallpaper || dock.savingExtension) return false
      var content = dock.settingsPanel.contentItem
      expect(dock.settingsPanel.selectedKey === "extensions", "Disabling a selected extension should return to Extensions")
      expect(!findControl(content, "text", "Wallpaper") && !findNamedObject(content, "wallpaperDirectoryPicker"),
        "A disabled extension should have no mounted settings page")
      dock.setExtensionEnabled("wallpaper", true)
      return true
    }},
    { name: "resume the wallpaper timer from saved settings", run: function() {
      if (!wallpaper || !wallpaper.ready || dock.savingExtension) return false
      expect(wallpaper.config.directory === wallpaperDirectory && wallpaper.rotation.running && !wallpaper.busy && !wallpaper.lastPath,
        "Restarting the extension should restore settings and wait for its interval")
      expect(wallpaperSlot(), "The Dock icon should be restored with the extension")
      var content = dock.settingsPanel.contentItem
      findControl(content, "text", "Wallpaper").clicked()
      var order = findNamedObject(content, "wallpaperRotationOrder")
      expect(order && order.value === "filename", "Rotation should default to filename order")
      order.changed("random")
      findControl(content, "text", "Apply").clicked()
      return true
    }},
    { name: "save random order without applying the unchanged directory", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.config.order === "random" && !wallpaper.lastPath && wallpaper.rotation.running,
        "Saving the order should keep the current wallpaper and resume the timer")
      wallpaper.rotation.triggered()
      return true
    }},
    { name: "use random order on a rotation tick", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === firstImage || wallpaper.lastPath === thirdImage, "A random tick should skip the current image")
      extensionWindow.openExtensionMenu(wallpaperSlot())
      var menu = extensionWindow.anchoredView
      expect(menu.menuActions.map(function(action) { return action.id }).join(",") === "directory,open,filename,random,export,settings"
        && menu.menuActions[3].checked, "Directory mode should offer both orders and mark the current one")
      menu.activateAction("filename")
      return true
    }},
    { name: "open the applied directory and pick a different directory from the Dock", run: function() {
      if (wallpaper.busy) return false
      var order = findNamedObject(dock.settingsPanel.contentItem, "wallpaperRotationOrder")
      expect(order.value === "filename" && wallpaper.rotation.running, "The menu order should synchronize to settings")
      extensionWindow.activateExtension(wallpaperSlot())
      extensionWindow.anchoredView.activateAction("open")
      extensionWindow.activateExtension(wallpaperSlot())
      extensionWindow.anchoredView.activateAction("directory")
      var picker = findNamedObject(extensionWindow.anchoredView, "wallpaperMenuDirectoryPicker")
      expect(picker && picker.visible, "Change directory should show the folder picker")
      picker.selectedFolder = Commons.Util.fileUrl(menuDirectory)
      picker.accepted()
      return true
    }},
    { name: "start Save As for the current background", run: function() {
      if (wallpaper.busy || wallpaper.menuBusy) return false
      expect(wallpaper.lastPath === menuDirectory + "/Current.PNG", "The new directory should apply its first image")
      extensionWindow.activateExtension(wallpaperSlot())
      extensionWindow.anchoredView.activateAction("export")
      return true
    }},
    { name: "save the current wallpaper to the chosen file", run: function() {
      var picker = findNamedObject(extensionWindow.anchoredView, "wallpaperMenuSavePicker")
      if (!picker.visible) return false
      expect(picker.sourcePath === wallpaper.lastPath && picker.defaultSuffix === "PNG", "Save As should use the actual wallpaper and suggest its extension")
      picker.selectedFile = Commons.Util.fileUrl(fixture + "/Saved # wallpaper.PNG")
      picker.accepted()
      return true
    }},
    { name: "drop images into the rotation directory without replacing the current wallpaper", run: function() {
      if (wallpaper.menuBusy) return false
      dropOnWallpaper([droppedImage, fixture + "/Duplicate/Current.PNG", wallpaperDirectory + "/0 fake.png"])
      return true
    }},
    { name: "hide the Dock icon while leaving wallpaper rotation active", run: function() {
      if (wallpaper.busy) return false
      expect(wallpaper.lastPath === menuDirectory + "/Current.PNG" && wallpaper.rotation.running,
        "Copying dropped images should leave the wallpaper and countdown active")
      expect(wallpaper.error.length > 0, "Invalid images and name collisions should be reported")
      findNamedObject(dock.settingsPanel.contentItem, "wallpaperDockIconSwitch").toggled()
      return true
    }},
    { name: "remove the wallpaper extension after saving the hidden icon preference", run: function() {
      if (wallpaper.busy || wallpaperSlot()) return false
      expect(wallpaper.rotation.running && !wallpaper.config.showDockIcon, "Hiding the icon should leave rotation active")
      dock.setExtensionEnabled("wallpaper", false)
      return true
    }},
    { name: "import an external extension with a settings page and declared fields", run: function() {
      if (wallpaper || dock.savingExtension) return false
      dock.addExternalExtension(fixture + "/Custom settings")
      return true
    }},
    { name: "use the external settings page in place of its inline fields", run: function() {
      if (!dock.extensions.instanceFor("example.custom-settings") || dock.savingExtension) return false
      var content = dock.settingsPanel.contentItem
      var toggle = findControl(content, "label", "Custom example")
      expect(toggle && !findControl(content, "label", "Inline flag"),
        "An extension with a page must not show its declared fields inline")
      findAction(toggle, "Settings for Custom example").clicked()
      expect(findItem(content, function(item) { return item.text === "Flag is enabled" }),
        "The extension's page should have access to its running instance and settings")
      dock.removeExternalExtension(fixture + "/Custom settings")
      return true
    }},
    { name: "return to Extensions after removing the active external settings page", run: function() {
      if (dock.extensions.sourceFor(fixture + "/Custom settings") || dock.savingExtension) return false
      expect(dock.settingsPanel.selectedKey === "extensions", "Removing the active extension should return to Extensions")
      return true
    }},
    { name: "select square Dock corners from General settings", run: function() {
      dock.settingsPanel.selectedKey = "general"
      var dropdown = findNamedObject(dock.settingsPanel.contentItem, "dockCornerStyle")
      var plate = findNamedObject(extensionWindow.contentItem, "dockPlate")
      expect(dropdown && dropdown.options.map(function(option) { return option.value }).join(",") === "square,rounded",
        "The corner style dropdown should offer square and rounded")
      expect(dropdown.value === "rounded" && plate && plate.radius > 0,
        "Existing settings should show rounded Dock corners by default")
      dropdown.value = "square"
      dropdown.changed("square")
      return true
    }},
    { name: "apply square corners and switch back to rounded", run: function() {
      if (dock.cornerStyle !== "square") return false
      var dropdown = findNamedObject(dock.settingsPanel.contentItem, "dockCornerStyle")
      var plate = findNamedObject(extensionWindow.contentItem, "dockPlate")
      expect(dropdown.value === "square" && plate.radius === 0,
        "The square selection should remove the live Dock corner radius")
      dropdown.value = "rounded"
      dropdown.changed("rounded")
      return true
    }},
    { name: "apply rounded Dock corners", run: function() {
      if (dock.cornerStyle !== "rounded") return false
      var dropdown = findNamedObject(dock.settingsPanel.contentItem, "dockCornerStyle")
      var plate = findNamedObject(extensionWindow.contentItem, "dockPlate")
      expect(dropdown.value === "rounded" && plate.radius > 0,
        "The rounded selection should restore the live Dock corner radius")
      return true
    }},
    { name: "preview Dock background transparency without saving", run: function() {
      var slider = findNamedObject(dock.settingsPanel.contentItem, "dockBackgroundTransparency")
      var plate = findNamedObject(extensionWindow.contentItem, "dockPlate")
      expect(slider && slider.value === 10 && Math.abs(plate.color.a - 0.9) < 0.01,
        "The unchanged appearance should default to 10 percent transparency")
      slider.moved(100)
      expect(plate.color.a === 0 && plate.border.color.a === 0 && dock.backgroundTransparency === 10,
        "A full transparency preview should hide the background and outline without saving")
      slider.released(0)
      expect(plate.color.a === 1 && dock.previewBackgroundTransparency === -1,
        "Releasing at zero should set an opaque background and clear the preview")
      slider.released(65)
      return true
    }},
    { name: "save the last background transparency selection", run: function() {
      if (privateFixtureSettings.savedSettings?.backgroundTransparency !== 65) {
        privateFixtureSettings.reload()
        return false
      }
      var slider = findNamedObject(dock.settingsPanel.contentItem, "dockBackgroundTransparency")
      var plate = findNamedObject(extensionWindow.contentItem, "dockPlate")
      expect(slider.value === 65 && Math.abs(plate.color.a - 0.35) < 0.01,
        "The slider and background should agree with the saved percentage")
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
