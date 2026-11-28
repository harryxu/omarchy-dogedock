# Changelog

## Unreleased

- Adjust Dock background transparency with a live slider in General settings.
- Choose square or rounded Dock corners in General settings.
- Enable Wallpaper to set a single image or rotate through the images in a directory.
- The optional Wallpaper Dock icon opens a menu for changing the source, choosing the rotation order, and saving a copy of the current wallpaper.
- Enabled extensions can provide their own settings page with a sidebar entry and a Settings button in the extension list.
- Removed background blur from the translucent Dock to keep its rounded edges smooth.
- Trash opens a compact confirmation window when emptying the Trash. Extensions that used the old `confirmation` menu field must provide their own dialog.

## v0.2.0

- Right-click a running app to list its open windows and bring a selected window to the front.
- The translucent Dock background blurs when Hyprland's `decoration.blur.enabled` is on.
- Drop local files and folders onto apps whose desktop entries accept file or URI arguments or declare D-Bus activation. The target app decides which items it can open.
- Drop files onto a pinned Folders extension icon to copy them into that directory. Existing items are preserved, and failures show a notification.
- Open the extension development guide directly from the Dock's Extensions settings.
- Updated the README and its Dock preview.

[Compare with the baseline](https://github.com/harryxu/omarchy-dogedock/compare/3c4c7af765bd4c1c2da9e904013bd395a5a07206...v0.2.0)
