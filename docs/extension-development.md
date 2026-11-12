# Develop a DogeDock extension

A Dock extension supplies one icon with its own state and actions. DogeDock draws the icon, tooltip, menu, and confirmation prompts. It creates one instance of each enabled extension and shares its state across all screens. External QML runs in the Omarchy Shell process with your user permissions. Enable extensions from directories you trust.

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
       "extensions": ["/home/your-name/dock-extensions/click-counter", "trash"]
     }
   }
   ```

5. Click the new icon and hover to check the count. Right-click it and choose **Reset**. Reorder the entries in the array and check that the count survives.

Add, remove, and reorder entries while the Shell is running. After editing your manifest or QML, run `omarchy restart shell` to reload the source. Use `quickshell log -f` to watch Shell logs and look for `DogeDock extension` followed by your path or ID. An invalid extension is skipped so the rest of the Dock can load.

## Manifest v1

| Field | Type | Rules |
| --- | --- | --- |
| `id` | String | Choose a unique ID such as `com.example.click-counter`. Start with a letter or digit. Subsequent characters can also include `.`, `_`, and `-`. Built-in IDs such as `trash` are reserved. |
| `apiVersion` | Number | Use `1`. DogeDock skips unsupported versions. |
| `entryPoint` | String | Path to a `.qml` file relative to `manifest.json`. The filename starts with an ASCII letter and can contain letters, digits, and underscores before `.qml`. Directory names can contain spaces and other filesystem characters. |

DogeDock uses the first valid manifest in configuration order if two external extensions declare the same ID. Use a new ID when distributing a different extension. A built-in uses the same manifest and QML interface. See the [Trash extension](../extensions/trash/Trash.qml) for a complete implementation with drop handling and background state updates.

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
