# AGENTS.md

## Project context

DogeDock is a QML and JavaScript plugin loaded by Omarchy Shell (Quickshell) on Hyprland. It started from the Dock in Omarchy 4.5.0 (`4.5.0-3` package). The installed copy at `$OMARCHY_PATH/shell/plugins/dock` (usually `/usr/share/omarchy/shell/plugins/dock`) is a reference for host integration. Make DogeDock changes in this checkout.

- `manifest.json` registers `harryxu.dogedock` as a replacement for `omarchy.dock`. Keep the `omarchy.dock` IPC target available to existing callers.
- `Dock.qml` is the service entry point. It reads Omarchy's Dock preferences, tracks apps and windows, and creates one `DockWindow.qml` per screen.
- `DockModel.js` contains the logic for pins, ordering, app matching, and window selection that can run without Quickshell.
- `DockWindow.qml` handles visibility, edge reveal, pointer input, and drag and drop. `DockToolTip.qml` renders the app name tooltip.
- `AppGrid.qml` is the menu entry point. Omarchy supplies its `shell.appLibrary` for app discovery, search, and launch, and its `service` for Dock interactions.

## Development

The [local checkout setup](docs/development.md#develop-from-a-local-checkout) describes how to link DogeDock for development. The Omarchy Shell session provides the `qs.Commons` and `qs.Ui` imports.

- Match the surrounding QML and JavaScript style, including two-space indentation.
- Use the shell's `Commons.Color` and `Style` values for colors, spacing, and typography.
- Keep position, auto-hide, and pins compatible with the `dock` section of Omarchy's `shell.json`. Keep the app grid in the shell's menu lifecycle so it receives the app library.

### Extension development boundary

Implement Dock extensions through the existing host interfaces. If those interfaces cannot support a required extension feature, explain the interface gap and proposed host changes to the user and obtain explicit confirmation before modifying host code. An extension development request alone does not authorize changes to the DogeDock host.

## Validation

Run `bash tests/run_all.sh` from the repository root on Omarchy. It runs the test suites and `omarchy plugin validate .` to check the manifest and entry points. The suite needs Node.js, Quickshell, `jq`, the system Python with PyGObject and Gio/GioUnix, and the installed Omarchy Shell QML modules.

- Run `node tests/dock_model.test.js` for pin normalization, ordering, terminal app matching, and window selection.
- Run `/usr/bin/python tests/test_file_drop.py` for the file drop CLI and Gio MIME matching against temporary files and desktop entries.
- Run `/usr/bin/python tests/run_extensions.py` for the offscreen QML integration tests. They exercise Dock settings, launcher IPC and app launch, icon geometry, extension lifecycle, and Trash actions. Keep settings and command side effects inside the temporary fixture.

After deploying, verify the affected interactions in the live Shell. The offscreen tests substitute the compositor surfaces. Use the live Shell for Wayland input, window focus, and visual checks.

- For visibility or input changes, try floating and tiled workspaces, auto-hide reveal, and a fullscreen window. Check a vertical edge if the change affects positioning or hit regions.
- For appearance changes, check the current theme, running indicators, and the instant app name tooltip. On hover, the pointer stays an arrow and the icon keeps its size.
- For window activation, click a running app on the current workspace and on another workspace. The pointer should stay where it was. Check minimized window restore when changing that path.
- For launcher changes, open the app grid with the Dock button or `omarchy-shell omarchy.dock apps`, then search for and launch an installed app.
- For file-drop changes, drag disposable files from a file manager onto a compatible app and onto Trash. Verify the highlight, the resulting action, and that the divider rejects drops.
- For Trash confirmation changes, cancel the dialog in the live Shell. Use an isolated Trash with disposable files to verify the confirm action.

## Deploy locally

Deploy every completed code change to the local Omarchy installation after validation passes.

1. Check `~/.config/omarchy/plugins/harryxu.dogedock`. If it links to this checkout, proceed to the restart. For a standalone copy, stage the validated files from the working tree, including new plugin files. Compare with the installed copy, account for any local changes, and keep a rollback copy outside the plugin search path. Replace the installed files while preserving its Git metadata and `~/.config/omarchy/shell.json`.
2. Run `omarchy restart shell`. Confirm that `omarchy plugin list` shows `harryxu.dogedock` enabled and `omarchy.dock` disabled, then check `omarchy-shell omarchy.dock refresh` and the affected live interactions above.
3. Report the deployment and verification results in the handoff. Include the rollback path when a backup was made.

## Releasing a version

1. Review the commits and diff from the last release tag through the intended
   release commit. In `CHANGELOG.md`, add any user-facing changes from that
   range that are missing from `Unreleased`, then move those notes under the
   new `vX.Y.Z` heading. Set `manifest.json` to the matching `X.Y.Z` version.
2. Run the relevant development checks above, including `omarchy plugin validate .`.
   Confirm the root manifest, README installation and removal instructions, and
   license are present. Check the preview if it changed. This plugin uses Omarchy's
   standard `omarchy plugin add` installation and enablement path.
3. Commit the release files, push the commit to the public default branch, and
   push a `vX.Y.Z` tag for that commit. Publish a stable GitHub Release in
   `harryxu/omarchy-dogedock` using that version's changelog entry as the
   release notes. Verify that the published tag and remote default branch HEAD
   point to the same commit. [GitHub Releases](https://github.com/harryxu/omarchy-dogedock/releases)
4. For a new version of the listed plugin, submit a marketplace Issue titled
   `[Verify]: DogeDock vX.Y.Z`. Choose **Verify and publish a newer
   upstream commit**, enter plugin ID `harryxu.dogedock`, repository URL
   `https://github.com/harryxu/omarchy-dogedock`, and the full 40-character
   SHA of the remote default branch HEAD. Check **Verification acknowledgment**.
   Use **Standard installation acknowledgment** when requesting removal of an
   explicit manual installation override. [Marketplace update form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=verify-plugin.yml). 
  Make sure to check both Verification acknowledgment and Standard installation acknowledgment in the issue.
5. Verify that the marketplace bot reports Quattro compatibility and the
   automated security baseline for the submitted SHA. After maintainer approval
   and deployment, verify the version, snapshot commit, and **Standard Installation**
   on the public listing. [Marketplace update rules](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/VERIFICATION.md#promoting-a-plugin-update) · [Plugin listing](https://plugins.omarchy.org/plugin.html?id=harryxu.dogedock)

## Agent skills

### Issue tracker

Use GitHub Issues for DogeDock tickets and specs. See [the issue tracker guide](docs/agents/issue-tracker.md).

### Triage labels

Use the five default triage labels when triaging requests. See [the label mapping](docs/agents/triage-labels.md).

### Domain docs

DogeDock uses a single-context layout. See [the domain docs guide](docs/agents/domain.md) when working with domain terms or decisions.
