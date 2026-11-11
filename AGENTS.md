# AGENTS.md

## Project context

DogeDock is a QML and JavaScript plugin loaded by Omarchy Shell (Quickshell) on Hyprland. It started from the Dock in Omarchy 4.5.0 (`4.5.0-3` package). The installed copy at `$OMARCHY_PATH/shell/plugins/dock` (usually `/usr/share/omarchy/shell/plugins/dock`) is a reference for host integration. Make DogeDock changes in this checkout.

- `manifest.json` registers `harryxu.dogedock` as a replacement for `omarchy.dock`. Keep the `omarchy.dock` IPC target available to existing callers.
- `Dock.qml` is the service entry point. It reads Omarchy's Dock preferences, tracks apps and windows, and creates one `DockWindow.qml` per screen.
- `DockModel.js` contains the logic for pins, ordering, app matching, and window selection that can run without Quickshell.
- `DockWindow.qml` handles visibility, edge reveal, pointer input, and drag and drop. `DockToolTip.qml` renders the app name tooltip.
- `AppGrid.qml` is the menu entry point. Omarchy supplies its `shell.appLibrary` for app discovery, search, and launch, and its `service` for Dock interactions.

## Development

Follow the local checkout setup in [README.md](README.md). With DogeDock enabled and its plugin directory linked to this checkout, `omarchy restart shell` loads the edited QML and JavaScript. The Omarchy Shell session provides the `qs.Commons` and `qs.Ui` imports.

- Match the surrounding QML and JavaScript style, including two-space indentation.
- Use the shell's `Commons.Color` and `Style` values for colors, spacing, and typography.
- Keep position, auto-hide, and pins compatible with the `dock` section of Omarchy's `shell.json`. Keep the app grid in the shell's menu lifecycle so it receives the app library.

## Validation

Run `omarchy plugin validate .` from the repository root. It checks the manifest and entry points. The live shell is needed to check how QML loads and behaves. This repository has no standalone build or automated test suite.

After reloading a linked checkout, check the interactions relevant to the change.

- For visibility or input changes, try floating and tiled workspaces, auto-hide reveal, and a fullscreen window. Check a vertical edge if the change affects positioning or hit regions.
- For appearance changes, check the current theme, running indicators, and the instant app name tooltip. On hover, the pointer stays an arrow and the icon keeps its size.
- For window activation, click a running app on the current workspace and on another workspace. The pointer should stay where it was. Check minimized window restore when changing that path.
- For launcher changes, open the app grid with the Dock button or `omarchy-shell omarchy.dock apps`, then search for and launch an installed app.
