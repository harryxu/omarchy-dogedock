# Develop a DogeDock extension

A Dock extension supplies icons with their own state and actions. DogeDock draws the icons, tooltips, menus, and confirmation prompts. It creates one instance of each enabled extension and shares it across all screens. API v2 supports any number of icons and extension-defined settings. DogeDock also loads existing single-icon API v1 extensions. External QML runs in the Omarchy Shell process with your user permissions. Enable extensions from directories you trust.

## Make a click counter

1. Create a directory for your extension, such as `/home/your-name/dock-extensions/click-counter`.
2. Save the following as `manifest.json` in that directory.

   ```json
   {
     "id": "com.example.click-counter",
     "apiVersion": 1,
     "entryPoint": "Counter.qml"
   }
   ```

3. Save this code as `Counter.qml` next to the manifest.

   ```qml
   import QtQml

   QtObject {
     id: counter

     property int clicks: 0
     readonly property string iconName: clicks > 0 ? "dialog-information" : "help-about"
     readonly property string tooltip: "Clicks: " + clicks
     readonly property var menuActions: [{ id: "reset", text: "Reset", enabled: clicks > 0 }]

     function activate() {
       counter.clicks++
     }

     function triggerAction(id) {
       if (id === "reset") counter.clicks = 0
     }
   }
   ```

4. With DogeDock enabled, add your actual absolute directory path to the `extensions` array in the existing `dock` object in `~/.config/omarchy/shell.json`. Keep the other settings in the file.

   ```json
   {
     "version": 1,
     "dock": {
       "extensions": [
         {"path": "/home/your-name/dock-extensions/click-counter", "enabled": true},
         {"id": "trash", "enabled": false}
       ]
     }
   }
   ```

5. Click the new icon and hover to check the count. Right-click it and choose **Reset**. Reorder the entries in the array and check that the count survives.

Add, remove, reorder, and toggle entries while the Shell is running. An object uses either `id` for a built-in or `path` for an external extension. `enabled` is a boolean and defaults to `true`. A plain ID or absolute path string also enables its extension. Configured extensions appear under **Settings → Extensions**, where you can enable them and edit any settings they declare. After editing your manifest or QML, run `omarchy restart shell` to reload the source. For errors, check the Extensions page and use `quickshell log -f` to look for `DogeDock extension` followed by your path or ID.

## Manifest

| Field | Type | Rules |
| --- | --- | --- |
| `id` | String | Choose a unique ID such as `com.example.click-counter`. Start with a letter or digit. Subsequent characters can also include `.`, `_`, and `-`. Built-in IDs such as `trash` and `folders` are reserved. |
| `name` | String | Optional display name for an external extension in the settings panel. Defaults to the ID. |
| `apiVersion` | Number | Use `1` for the single-icon API or `2` for the API with multiple icons and settings. |
| `entryPoint` | String | Path to a `.qml` file relative to `manifest.json`. The filename starts with an ASCII letter and can contain letters, digits, and underscores before `.qml`. Directory names can contain spaces and other filesystem characters. |
| `settings` | Array | Optional ordered list of field declarations for API v2. |

DogeDock uses the first enabled extension with a valid manifest in configuration order if two external extensions declare the same ID. Use a new ID when distributing a different extension. A built-in uses the same manifest and QML interface. The [Trash extension](../extensions/trash/Trash.qml) implements v1 with drop handling and background state updates.

## QML API v2

Use a nonvisual root object such as `QtObject` with `required property var settings` and an `icons` array. DogeDock supplies the resolved `settings` object at creation and replaces it when settings change. Treat it as read-only. Bind `icons` to your settings or extension state, or assign a new array when an icon changes.

Each icon has a nonempty string `id` unique within the extension, plus `iconName` or `iconSource`. The optional `tooltip`, `menuActions`, and `acceptsFiles` use the same rules as v1. Publish an empty array to show zero icons. DogeDock displays the icons in array order within the extension's group. Keep the ID stable across reorder and state changes so DogeDock can direct interactions to the same icon.

Define the callbacks your extension uses on the root object.

| Callback | Arguments |
| --- | --- |
| `activate(iconId)` | The icon that was left-clicked. |
| `triggerAction(iconId, actionId)` | The icon and the selected menu action. DogeDock checks that the action is enabled and that any required confirmation was accepted. |
| `dropFiles(iconId, uris)` | The icon accepting the drop and an array of local file URI strings. |

### Declare settings

Each field in the manifest's `settings` array has a unique `key`, a user-facing `label`, a `type`, and a valid `default`. Start keys with an ASCII letter and use letters, digits, underscores, or hyphens after that. Set `multiple: true` for a list. Lists use an array default. DogeDock renders the fields in manifest order when the extension is enabled.

| Type | Value |
| --- | --- |
| `string` | A text string. |
| `boolean` | `true` or `false`. |
| `number` | A finite JSON number. The editor accepts a decimal point and exponent notation. |
| `choice` | A string from `options`, an array of objects with unique nonempty string `value` keys and display `label` strings. |
| `directory` | An absolute local path string. A single directory can be empty. Directory lists use distinct paths and omit trailing slashes except for `/`. |

The saved values are stored by field key in the `settings` object of the corresponding `dock.extensions` entry in `~/.config/omarchy/shell.json`. An omitted field uses the manifest default. Invalid saved values are marked in the panel and use the default at runtime. A list with both valid and invalid entries uses the valid entries in order. Disabling an extension preserves its settings.

### Example with a directory list

This manifest declares one list field. Configured paths become separate icons.

```json
{
  "id": "com.example.folder-links",
  "name": "Folder Links",
  "apiVersion": 2,
  "entryPoint": "FolderLinks.qml",
  "settings": [
    { "key": "directories", "label": "Directories", "type": "directory", "multiple": true, "default": [] }
  ]
}
```

```qml
import QtQml
import Quickshell
import qs.Commons

QtObject {
  required property var settings

  readonly property var icons: settings.directories.map(function(path) {
    return { id: path, iconName: "folder", tooltip: path }
  })

  function activate(iconId) {
    Quickshell.execDetached(["gio", "open", Util.fileUrl(iconId)])
  }
}
```

Add the extension's absolute path to `dock.extensions`, enable it in **Settings → Extensions**, and use **Add directory…** to select two directories. Each should appear immediately. Reorder them in the panel and check that each still opens its own directory. The built-in [Folders extension](../extensions/folders/Folders.qml) also reports unavailable directories.

An entry with two saved directories looks like this inside `dock.extensions`.

```json
{
  "path": "/home/your-name/dock-extensions/folder-links",
  "enabled": true,
  "settings": {
    "directories": ["/home/your-name/Downloads", "/home/your-name/Projects"]
  }
}
```

## QML API v1

Use a nonvisual root object such as `QtObject`. Provide `iconName` or `iconSource`. The other members are optional. Define state with QML properties so DogeDock can react to changes.

| Member | Type | Behavior |
| --- | --- | --- |
| `iconName` | `string` | A name from the current icon theme. Change it to reflect state. DogeDock provides a generic fallback when the name cannot be resolved. |
| `iconSource` | `url` | A local `file:///` URL. It takes priority over `iconName`. Use `Qt.resolvedUrl("icons/ready.svg")` for an asset shipped with the extension. |
| `tooltip` | `string` | Hover text. Defaults to the manifest ID. Set an empty string to hide it. |
| `activate()` | Function | Called on left click. |
| `menuActions` | `var` | An ordered array of action objects. Replace the array when actions change, or bind it to properties as in the counter example. |
| `triggerAction(id)` | Function | Called with the selected action's ID when the action is enabled and any confirmation has been accepted. |
| `acceptsFiles` | `bool` | Defaults to `false`. Set it to `true` to accept local file and directory drops. Bind it to readiness if needed. |
| `dropFiles(uris)` | Function | Receives a JavaScript array of local file URI strings. Treat the URI and the decoded filename as distinct values. |

Each menu action needs a unique string `id` and a string `text`. `enabled` defaults to `true`. An optional `confirmation` object supplies `title`, `message`, and `acceptText` strings. For example, an action that discards saved state could declare the following.

```qml
readonly property var menuActions: [{
  id: "discard",
  text: "Discard saved state…",
  enabled: hasSavedState,
  confirmation: {
    title: "Discard saved state?",
    message: "This will permanently remove the saved state.",
    acceptText: "Discard"
  }
}]
```

For file drops, DogeDock accepts URI transfer when the drag source offers `CopyAction`. The extension decides what to do with the items after receiving the URIs. Use argument arrays or a file API to pass URIs to your code. Report failures from your operation and keep Shell callbacks short. For long tasks, use a child `Process` or another asynchronous API. The instance and its child QML objects are destroyed when the extension is disabled, so keep work that belongs to the instance on those objects.
