# DogeDock

DogeDock is a user plugin based on the Dock shipped with [Omarchy 4.5.0](https://github.com/omacom/omarchy/tree/v4.5.0/shell/plugins/dock). The starting code was copied from the installed package `4.5.0-3`. It runs as a service in Omarchy Shell and uses the host's Quickshell components and Dock preferences. The original MIT license is included.

The plugin ID is `harryxu.dogedock`. The `clonedFrom` manifest entry lets Omarchy replace the built-in Dock and retain its existing IPC calls. DogeDock is available in every regular workspace layout and hides when an application is fullscreen.

To install from a local checkout, run the following commands from the project root.

```sh
omarchy plugin validate .
ln -s "$PWD" ~/.config/omarchy/plugins/harryxu.dogedock
omarchy-shell shell rescanPlugins
```

Once `harryxu.dogedock` appears in `omarchy plugin list`, activate it.

```sh
omarchy plugin enable harryxu.dogedock
omarchy restart shell
```

Edit the QML and JavaScript files in this checkout. Run `omarchy restart shell` to load edits from the linked directory and clear any cached QML components.

To restore the built-in Dock, run `omarchy plugin disable harryxu.dogedock`. Omarchy restores the built-in when this clone originally replaced it. Remove the symbolic link with `unlink ~/.config/omarchy/plugins/harryxu.dogedock` and restart the Shell.

