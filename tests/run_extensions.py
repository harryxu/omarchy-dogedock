"""Run DogeDock integration tests against an isolated Quickshell instance."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
TESTS = REPO / "tests"


def external_entry(root, **settings):
    return {"path": str(root / "Multi"), "enabled": False, "settings": {
        "names": ["First", "Second"], "show": "wrong", "future": "preserve this", **settings,
    }}


def write_json(path, value):
    path.write_text(json.dumps(value) + "\n", encoding="utf-8")


def prepare_fixture(root):
    # Substitute compositor surfaces in the fixture only. The Dock window and
    # service, launcher, settings, and extensions run as QML.
    plugin = root / "DogeDock"
    plugin.mkdir()
    for filename in (
        "Dock.qml", "DockModel.js", "DockSettings.qml", "DockExtensions.qml", "ExtensionSettingsModel.js", "IconGeometry.js",
        "DockFileDrop.qml", "DockToolTip.qml", "DockAppIcon.qml", "FileDrop.py",
    ):
        shutil.copy2(REPO / filename, plugin / filename)
    surfaces = plugin / "test_surfaces"
    surfaces.mkdir()
    shutil.copy2(TESTS / "OverlayWindow.qml", surfaces / "OverlayWindow.qml")
    shutil.copy2(TESTS / "DockSurface.qml", surfaces / "DockSurface.qml")
    dock_window = (REPO / "DockWindow.qml").read_text(encoding="utf-8")
    dock_window = 'import "test_surfaces" as TestSurfaces\n' + dock_window.replace("PanelWindow {", "TestSurfaces.DockSurface {")
    dock_window = re.sub(
        r'(?m)^ {2,4}(?:WlrLayershell\.\w+:|visible: !remapGuard|color: "transparent"|exclusionMode:|anchors \{ top: true;).*$',
        "", dock_window,
    )
    dock_window = re.sub(
        r"(?ms)^  (?:anchors|mask: Region|ScreenMoveRemap|HyprlandFocusGrab) \{.*?^  \}",
        "", dock_window,
    )
    dock_window = dock_window.replace(
        "readonly property bool shown: !!dock && !!workspace && fullscreenMode < 2",
        "readonly property bool shown: !!dock",
    )
    (plugin / "DockWindow.qml").write_text(dock_window, encoding="utf-8")
    app_grid = (REPO / "AppGrid.qml").read_text(encoding="utf-8")
    native_surface = '  OverlayWindow {\n    id: panel\n    shown: root.opened\n    WlrLayershell.namespace: "omarchy-dock-apps"'
    assert app_grid.count(native_surface) == 1, "Update the AppGrid surface fixture"
    app_grid = 'import "test_surfaces" as TestSurfaces\n' + app_grid.replace(
        native_surface, "  TestSurfaces.OverlayWindow {\n    id: panel\n    shown: root.opened"
    )
    (plugin / "AppGrid.qml").write_text(app_grid, encoding="utf-8")
    for directory in ("settings", "extensions"):
        shutil.copytree(REPO / directory, plugin / directory)

    for name, manifest, entry_point in (
        ("First # extension", {"id": "example.first", "apiVersion": 1}, "Example.qml"),
        ("Duplicate", {"id": "example.first"}, "Example.qml"),
        ("Second", {"id": "example.second"}, "NoSettings.qml"),
        ("Reserved", {"id": "trash"}, "Example.qml"),
    ):
        directory = root / name
        directory.mkdir()
        write_json(directory / "manifest.json", {**manifest, "entryPoint": entry_point})
        shutil.copy2(TESTS / entry_point, directory / entry_point)

    invalid_icons = root / "Invalid icons"
    invalid_icons.mkdir()
    write_json(invalid_icons / "manifest.json", {"id": "example.invalid-icons", "entryPoint": "InvalidIcons.qml"})
    (invalid_icons / "InvalidIcons.qml").write_text(
        'import QtQml\nQtObject { property var icons; property string iconName: "folder" }\n',
        encoding="utf-8",
    )

    empty_settings = root / "Empty settings"
    empty_settings.mkdir()
    write_json(empty_settings / "manifest.json", {
        "id": "example.empty-settings", "entryPoint": "EmptySettings.qml", "settings": [],
    })
    (empty_settings / "EmptySettings.qml").write_text(
        """import QtQml
QtObject {
  required property var settings
  readonly property var icons: Object.keys(settings).length === 0 ? [{ id: "ready", iconName: "folder" }] : []
}
""",
        encoding="utf-8",
    )

    multi = root / "Multi"
    multi.mkdir()
    write_json(multi / "manifest.json", {
        "id": "example.multi", "name": "Multi Example", "entryPoint": "MultiIcon.qml",
        "settings": [
            {"key": "names", "label": "Icon names", "type": "string", "multiple": True, "default": []},
            {"key": "show", "label": "Show icons", "type": "boolean", "default": True},
            {"key": "limit", "label": "Icon limit", "type": "number", "default": 5},
            {"key": "palette", "label": "Palette", "type": "choice", "default": "warm",
             "options": [{"value": "warm", "label": "Warm"}, {"value": "cool", "label": "Cool"}]},
        ],
    })
    shutil.copy2(TESTS / "MultiIcon.qml", multi / "MultiIcon.qml")
    invalid = root / "Invalid settings"
    invalid.mkdir()
    write_json(invalid / "manifest.json", {
        "id": "example.invalid", "entryPoint": "MultiIcon.qml",
        "settings": [{"key": "invalid", "label": "Broken", "type": "number", "default": "oops"}],
    })
    shutil.copy2(TESTS / "MultiIcon.qml", invalid / "MultiIcon.qml")
    for name in ("First # folder % ready", "Second folder"):
        (root / name).mkdir()
    nested = root / "First # folder % ready" / "Nested # folder"
    nested.mkdir()
    (nested / "notes %20.txt").touch()
    (nested.parent / "top-level.txt").touch()
    for index in range(60):
        (root / "Second folder" / f"Entry {index:02}.txt").touch()

    home = root / "home"
    config = home / ".config/omarchy/shell.json"
    config.parent.mkdir(parents=True)
    write_json(config, {
        "version": 1, "bar": {"layout": {section: [] for section in (
            "left", "centerBegin", "center", "centerEnd", "right",
        )}}, "plugins": [], "idle": {"lock": 300},
        "dock": {
            "position": "left", "pinned": ["example.desktop"],
            "sizeLevel": 5, "extensions": ["folders"],
        },
    })

    bin_dir = root / "bin"
    bin_dir.mkdir()
    for command in ("gio", "notify-send", "omarchy-shell"):
        (bin_dir / command).symlink_to(TESTS / "fake_command.py")
    (root / "trash-count").write_text("0", encoding="utf-8")
    (root / "runtime").mkdir(mode=0o700)
    shutil.copy2(TESTS / "Extensions.qml", root / "shell.qml")
    return config, bin_dir


def run(root):
    config, bin_dir = prepare_fixture(root)
    omarchy = Path(os.environ.get("OMARCHY_PATH") or "/usr/share/omarchy")
    for module in ("Commons", "Ui"):
        target = omarchy / "shell" / module
        if not (target / "qmldir").is_file():
            raise RuntimeError(f"Omarchy QML module is missing: {target}")
        (root / module).symlink_to(target, target_is_directory=True)
    (root / "qs").symlink_to(omarchy / "shell", target_is_directory=True)

    config_home = root / "config # home"
    private_config = config_home / "harryxu.dogedock/settings.json"
    environment = os.environ | {
        "DOGEDOCK_TEST_ROOT": str(root),
        "HOME": str(root / "home"),
        "OMARCHY_PATH": str(omarchy),
        "PATH": f"{bin_dir}:{os.environ['PATH']}",
        "QML_IMPORT_PATH": str(root),
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QPA_PLATFORMTHEME": "",
        "QT_QUICK_BACKEND": "software",
        "XDG_CACHE_HOME": str(root / "cache"),
        "DOGEDOCK_TEST_EXTENSIONS": json.dumps(["trash", external_entry(root), str(root / "Invalid settings")]),
        "XDG_CONFIG_HOME": str(config_home),
        "XDG_RUNTIME_DIR": str(root / "runtime"),
    }
    for name in ("WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS"):
        environment.pop(name, None)
    result = subprocess.run(
        ["quickshell", "--no-color", "-p", str(root / "shell.qml")],
        env=environment, timeout=25, check=True, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    print(result.stdout, end="")
    if "PASS: DogeDock extension integration" not in result.stdout:
        raise RuntimeError("Quickshell exited before the integration assertions finished")

    shell = json.loads(config.read_text(encoding="utf-8"))
    assert shell["idle"] == {"lock": 300}, shell
    assert shell["dock"] == {
        "position": "right", "autohide": True, "pinned": ["example.desktop"],
        "sizeLevel": 5, "extensions": ["folders"],
    }, shell
    settings = json.loads(private_config.read_text(encoding="utf-8"))
    assert settings == {
        "sizeLevel": 6, "future": "preserve this",
        "extensions": [
            {"id": "trash", "enabled": True},
            external_entry(root, show=False, limit=15, palette="cool"),
            str(root / "Invalid settings"),
            {"id": "folders", "enabled": True, "settings": {"directories": [
                str(root / "Second folder"), str(root / "First # folder % ready"),
            ]}},
        ],
    }, settings
    calls = [json.loads(line) for line in (root / "calls.jsonl").read_text().splitlines()]
    # Open and drop use independent processes, so their log order can vary.
    assert sorted(args for args in calls if args[0] == "gio") == [
        ["gio", "open", (root / "First # folder % ready").as_uri()],
        ["gio", "open", (root / "First # folder % ready" / "Nested # folder").as_uri()],
        ["gio", "open", (root / "First # folder % ready" / "Nested # folder" / "notes %20.txt").as_uri()],
        ["gio", "open", "trash:///"],
        ["gio", "trash", "--", "file:///example/keep%20spaces", "file:///example/failed"],
        ["gio", "trash", "--empty"],
    ], calls
    notices = {args[-2]: args[-1] for args in calls if args[0] == "notify-send"}
    assert len(notices) == 2 and "&lt;failed&gt;" in notices["Could not move some items to the Trash."], notices
    assert notices["Folder is unavailable."].endswith("Unavailable &lt;folder&gt;"), notices
    print("PASS: saved settings, directory and Trash actions, and failure notifications")


if __name__ == "__main__":
    try:
        with tempfile.TemporaryDirectory(prefix="dogedock-test-") as temporary:
            run(Path(temporary))
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        sys.stderr.write(str(error) + "\n")
        if isinstance(error.stdout, bytes):
            sys.stderr.write(error.stdout.decode(errors="replace"))
        elif error.stdout:
            sys.stderr.write(error.stdout)
        sys.exit(1)
