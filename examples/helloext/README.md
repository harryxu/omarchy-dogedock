# Hello Extension

This example stays uninstalled until you add it yourself. Open DogeDock's
**Settings → Extensions → Add external extension…** and select this `helloext`
directory (the directory containing `manifest.json`).

Under **Hello Extension → Names**, enter a name and click **Add**. Each nonblank
name creates a Dock icon showing its first character. Duplicate names have
separate icons. Edit, reorder, or remove names using the standard settings
controls. Click an icon to show `Hello <name>`; use **Close**, click outside, or
click the icon again to dismiss it.

The example demonstrates a manifest with a list of text settings, reactive
multiple icons, stable icon IDs, an extension-owned `iconComponent` that renders
the first character, and an anchored custom popup.
Disable the extension to retain its names without displaying icons. **Remove**
unloads it and removes its saved settings; the example directory stays intact.
