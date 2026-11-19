const assert = require("node:assert/strict")
const test = require("node:test")
const dock = require("../DockModel.js")

test("Dock preferences normalize edges and respect explicitly empty pins", () => {
  const defaults = { pinned: ["browser.desktop"] }
  assert.equal(dock.normalizePosition(" LEFT "), "left")
  assert.equal(dock.normalizePosition("unknown"), "bottom")
  assert.equal(dock.isVertical("right"), true)
  assert.equal(dock.isVertical("top"), false)
  assert.deepEqual(dock.pinnedIds({}, defaults), ["browser"])
  assert.deepEqual(dock.pinnedIds({ pinned: [] }, defaults), [])
  assert.deepEqual(dock.pinnedIds({ pinned: [" editor.desktop ", "editor", "", "terminal"] }, defaults), [
    "editor", "terminal"
  ])
})

test("Terminal windows can map to explicit app IDs and Omarchy TUI launchers", () => {
  const entries = [
    { id: "editor", command: ["/usr/bin/nvim"], runInTerminal: true },
    { id: "web", execString: "terminal --app-id=example.web" },
    { id: "helper", command: ["helper"], runInTerminal: false }
  ]
  assert.equal(dock.claimingEntryId("example.web", entries), "web")
  assert.equal(dock.claimingEntryId("org.omarchy.nvim", entries), "editor")
  assert.equal(dock.claimingEntryId("example", entries), "")
  assert.equal(dock.claimingEntryId("org.omarchy.helper", entries), "")
})

test("Dock groups windows by app and keeps minimized windows available to restore", () => {
  const editor = { key: "editor", hasEntry: true, workspaceId: 1 }
  const editorOther = { key: "editor", hasEntry: true, workspaceId: 2 }
  const minimized = { key: "minimized-app", minimized: true, workspaceId: -2 }
  const windows = [
    editor,
    { key: "background-helper", hasEntry: false, workspaceId: 1 },
    { key: "scratchpad", hasEntry: true, workspaceId: -1 },
    editorOther,
    minimized
  ]
  assert.deepEqual(dock.buildItems(["browser", "editor"], windows), [
    { key: "browser", pinned: true, windows: [] },
    { key: "editor", pinned: true, windows: [editor, editorOther] },
    { key: "minimized-app", pinned: false, windows: [minimized] }
  ])
  assert.equal(dock.isMinimizedWorkspace("special:minimized"), true)
  assert.equal(dock.isMinimizedWorkspace("special:scratchpad"), false)
})

test("Dock reordering keeps active slots stable and retains hidden pins on save", () => {
  const items = dock.buildItems(["browser", "editor"], [{ key: "terminal", hasEntry: true, workspaceId: 1 }])
  const order = dock.orderWithKeyAt(["browser", "editor"], "editor", 0)
  assert.deepEqual(dock.orderItems(items, [...order, "gone", "browser"]).map(item => item.key), [
    "editor", "browser", "terminal"
  ])
  assert.deepEqual(dock.pinsInOrder(["editor", "terminal", "browser"], { editor: true, browser: true }, [
    "browser", "uninstalled", "editor"
  ]), ["editor", "browser", "uninstalled"])
  assert.equal(dock.dropIndex(1, 23, 50, 3), 1)
  assert.equal(dock.dropIndex(1, 27, 50, 3), 2)
  assert.equal(dock.dropIndex(1, -500, 50, 3), 0)
})

test("App IDs matching object properties still group and reorder", () => {
  const minimized = { key: "constructor", hasEntry: false, minimized: true, workspaceId: -2 }
  const items = dock.buildItems(["__proto__"], [minimized])
  assert.deepEqual(items, [
    { key: "__proto__", pinned: true, windows: [] },
    { key: "constructor", pinned: false, windows: [minimized] }
  ])

  const order = ["toString", "constructor", "constructor"]
  assert.deepEqual(dock.orderItems(items, order), [items[1], items[0]])
})

test("Window activation prefers the current workspace, then minimized, then other workspaces", () => {
  const windows = [
    { workspaceId: 2 },
    { workspaceId: -2, minimized: true },
    { workspaceId: 1 },
    { workspaceId: 1 }
  ]
  assert.equal(dock.pickWindow([], 1), -1)
  assert.equal(dock.pickWindow(windows, 1), 2)
  assert.equal(dock.pickWindow(windows, 3), 1)

  for (const [active, next] of [[2, 3], [3, 1], [1, 0], [0, 2]]) {
    assert.equal(dock.pickWindow(windows.map((window, index) => ({ ...window, activated: index === active })), 1), next)
  }
})
