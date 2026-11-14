# Order extensions through Dock settings

The `dock.extensions` array in `shell.json` enables Dock extensions in display order. Use an extension ID for a built-in extension and an absolute directory path for an external extension. DogeDock places the extensions after the application icons, so `dock.pinned` can continue to store desktop application IDs and application drag reordering can keep using Omarchy's pin commands. An omitted or empty array enables zero extensions.

Settings changes take effect while the Shell is running. Reordering keeps existing instances alive, and DogeDock logs and skips extensions that fail to load. Source edits take effect after a Shell restart, which also refreshes the QML engine's component cache.

An entry can be an object with a built-in `id` or an absolute `path` and an optional boolean `enabled`. Disabled entries retain their settings and position in the array. Strings and objects with no `enabled` field enable the extension.
