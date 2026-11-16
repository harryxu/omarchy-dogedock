import QtQuick
import Quickshell
import "DogeDock" as Doge

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

  Doge.Dock { id: dock }

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
