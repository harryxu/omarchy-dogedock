# DogeDock development

The plugin ID is `harryxu.dogedock`. The `clonedFrom` manifest entry lets Omarchy replace the built-in Dock while retaining its existing IPC calls.

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

## Validation

Run `bash tests/run_all.sh` from the project root to run the automated tests and validate the plugin. The test suite also needs Node.js. See [validation in AGENTS.md](../AGENTS.md#validation) for dependencies, individual test commands, and live Shell checks.

## Write a Dock extension

The [extension development guide](extension-development.md) covers custom icon rendering, settings, callbacks, and migration from older extensions. The [Hello Extension example](../examples/helloext/README.md) demonstrates name icons and a closable greeting.
