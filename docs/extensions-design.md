# Dock extensions v1 design

See the [extension development guide](extension-development.md) for the shipped API, an external extension example, and debugging instructions.

## Enabling extensions

Add `extensions` inside the `dock` section of `~/.config/omarchy/shell.json`.

```json
{
  "version": 1,
  "dock": {
    "extensions": ["trash", "/home/harry/dock-extensions/example"]
  }
}
```

Extensions appear after application icons in array order, with one icon per enabled extension on every Dock. Changing the array enables, disables, or reorders extensions immediately. Reordering reuses active instances. Restart Omarchy Shell after editing an extension's manifest or QML source.

## Interface design

DogeDock validates the manifest before loading the QML entry point. The entry point supplies one nonvisual object with reactive properties and callbacks. All Dock windows share the instance, so a background monitor runs once per extension. DogeDock owns icon sizing, tooltip placement, menu rendering, confirmations, and drop dispatch.

## Built-in Trash

Enable `trash` to show the system Trash. The icon follows the system Trash's empty or nonempty state, including changes made in a file manager. Left-click the icon or choose **Open** from its context menu to open the Trash in the file manager. **Empty Trash** asks for confirmation before permanent deletion. The action is disabled while the Trash is empty or its state is unavailable.

Dropping local files and directories asks the extension to move each entry into the system Trash. Successful entries remain recoverable in the file manager. A failed entry stays at its original location, and the extension reports failures even when some entries succeed. DogeDock must negotiate a drag action that leaves source files under the extension's control. Wayland sources may delete originals after an accepted move action, so verify this with a real file manager before shipping.

## Verification

- Enable `trash` and an external example, then reorder and disable them while the Dock runs. Check that a malformed extension does not prevent other icons from loading and that every screen shows the same state.
- Open Trash and check icon changes after adding and restoring disposable entries in the file manager. Cancel and confirm **Empty Trash** using an isolated Trash that contains only disposable files.
- Drag disposable files and directories onto Trash on a visible Dock and an auto-hidden Dock. Check partial failure, a vertical edge, and that ordinary app drop and pin behavior still work.
