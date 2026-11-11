# DogeDock

DogeDock is a user plugin based on the Dock shipped with [Omarchy 4.5.0](https://github.com/omacom/omarchy/tree/v4.5.0/shell/plugins/dock). The starting code was copied from the installed package `4.5.0-3`. It runs as a service in Omarchy Shell and uses the host's Quickshell components and Dock preferences. The original MIT license is included.

The plugin ID is `harryxu.dogedock`. The `clonedFrom` manifest entry lets Omarchy replace the built-in Dock and retain its existing IPC calls.

## Features

- The built-in Dock is limited to floating workspaces. DogeDock is available in every regular workspace layout, including Dwindle and Scrolling, and hides when an application is fullscreen.
- A rounded, translucent background uses the current Omarchy theme and sits slightly in from the screen edge. The icons have equal space above and below them. Running apps get a small dot below the icon within that padding. The app launcher uses a more compact grid icon.
- App icons display at full opacity, even while launching or when a pinned app is closed.
- Hovering over a dock icon keeps the standard arrow cursor and the icon's size. Hovering over an app icon also shows its name immediately in a themed tooltip. On a bottom dock, the tooltip appears above the icon.
- Clicking a running app brings its window to the front and keeps the pointer in place, including when the window is on another workspace.

DogeDock registers its app grid as an Omarchy menu so the launcher can list and search installed apps through Omarchy Shell.

## Install from GitHub

DogeDock is distributed directly through GitHub. In a terminal on Omarchy, run the install command, confirm the prompt, then restart the shell.

```sh
omarchy plugin add https://github.com/harryxu/omarchy-dogedock.git --enable
omarchy restart shell
```

Enabling DogeDock automatically replaces the built-in `omarchy.dock`. Use `omarchy plugin list` to check that `harryxu.dogedock` is enabled and `omarchy.dock` is disabled.

## Restore the built-in Dock

```sh
omarchy plugin disable harryxu.dogedock
omarchy restart shell
```

Omarchy restores the built-in Dock if it was enabled before DogeDock took over. If you had already disabled it, run `omarchy plugin enable omarchy.dock` to turn it back on. To uninstall DogeDock, run `omarchy plugin remove harryxu.dogedock`.

## Develop from a local checkout

For local development, use a linked checkout. If you already installed DogeDock from GitHub, remove that installation first to free up the plugin ID. Run these commands from the project root.

```sh
omarchy plugin validate .
mkdir -p ~/.config/omarchy/plugins
ln -s "$PWD" ~/.config/omarchy/plugins/harryxu.dogedock
omarchy-shell shell rescanPlugins
```

Once `harryxu.dogedock` appears in `omarchy plugin list`, activate it.

```sh
omarchy plugin enable harryxu.dogedock
omarchy restart shell
```

Edit the QML and JavaScript files in this checkout. Run `omarchy restart shell` to load edits from the linked directory and clear any cached QML components.

To remove the development link, disable DogeDock first, then run `unlink ~/.config/omarchy/plugins/harryxu.dogedock` and restart the shell.
