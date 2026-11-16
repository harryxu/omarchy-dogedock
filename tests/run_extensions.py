"""Run extension integration tests against an isolated Quickshell instance."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
TESTS = REPO / "tests"
EXTERNAL = {"path": "/example/disabled", "enabled": False}


def write_json(path, value):
    path.write_text(json.dumps(value) + "\n", encoding="utf-8")


def prepare_fixture(root):
    # The offscreen Qt backend cannot create a layer-shell window. Keep the real
    # Dock service, settings panel, extension loader and Trash entry point.
    plugin = root / "DogeDock"
    plugin.mkdir()
    for filename in ("Dock.qml", "DockModel.js", "DockExtensions.qml"):
        shutil.copy2(REPO / filename, plugin / filename)
    (plugin / "DockWindow.qml").write_text(
        "import QtQuick\nItem { required property var dock; required property var screen }\n",
        encoding="utf-8",
    )
    for directory in ("settings", "extensions"):
        shutil.copytree(REPO / directory, plugin / directory)

    for name, extension_id, version in (
        ("First # extension", "example.first", 1),
        ("Duplicate", "example.first", 1),
        ("Second", "example.second", 1),
        ("Incompatible", "example.incompatible", 2),
        ("Reserved", "trash", 1),
    ):
        directory = root / name
        directory.mkdir()
        write_json(directory / "manifest.json", {
            "id": extension_id, "apiVersion": version, "entryPoint": "Example.qml",
        })
        shutil.copy2(TESTS / "Example.qml", directory / "Example.qml")

    home = root / "home"
    config = home / ".config/omarchy/shell.json"
    config.parent.mkdir(parents=True)
    write_json(config, {"version": 1, "dock": {
        "position": "left", "pinned": ["example.desktop"],
        "extensions": ["trash", EXTERNAL],
    }})

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
        "XDG_CONFIG_HOME": str(root / "home/.config"),
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

    dock = json.loads(config.read_text(encoding="utf-8"))["dock"]
    assert dock == {
        "position": "left", "pinned": ["example.desktop"],
        "extensions": [{"id": "trash", "enabled": True}, EXTERNAL],
    }, dock
    calls = [json.loads(line) for line in (root / "calls.jsonl").read_text().splitlines()]
    # Open and drop use independent processes, so their log order can vary.
    assert sorted(args for args in calls if args[0] == "gio") == [
        ["gio", "open", "trash:///"],
        ["gio", "trash", "--", "file:///example/keep%20spaces", "file:///example/failed"],
        ["gio", "trash", "--empty"],
    ], calls
    notices = [args for args in calls if args[0] == "notify-send"]
    assert len(notices) == 1 and "Could not move some items to the Trash." in notices[0], notices
    assert "&lt;failed&gt;" in notices[0][-1], notices
    print("PASS: saved settings, open, file drop, empty, and partial failure notification")


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
