"""Persist the wallpaper settings and apply an image through Omarchy."""

import json
import os
from pathlib import Path
import random
import subprocess
import sys
import tempfile

from gi.repository import Gio


IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"}
IMAGE_TYPES = {"image/jpeg", "image/png", "image/gif", "image/bmp", "image/webp"}


def is_image(path):
    if path.suffix.lower() not in IMAGE_SUFFIXES or not path.is_file():
        return False
    try:
        with path.open("rb") as image:
            kind, uncertain = Gio.content_type_guess(None, image.read(4096))
            return not uncertain and kind in IMAGE_TYPES
    except OSError:
        return False


def save_settings(path, settings):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        try:
            json.dump(settings, output)
            output.write("\n")
            output.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def rotation_image(directory, operation, last_path, order):
    with os.scandir(directory) as entries:
        paths = sorted((Path(entry.path) for entry in entries), key=lambda path: (path.name.casefold(), path.name))

    images = {}
    for path in paths:
        if is_image(path):
            try:
                images.setdefault(path.resolve(strict=True), path)
            except (OSError, RuntimeError):
                continue
    if not images:
        return None, False

    current_link = Path.home() / ".local/state/omarchy/current/background"
    try:
        current = current_link.resolve(strict=True)
    except (OSError, RuntimeError):
        current = None

    candidates = list(images.items())
    if operation in ("previous", "next"):
        # Manual navigation follows filenames, including in random rotation mode.
        current_index = next((i for i, path in enumerate(images) if path == current), -1)
        if current_index < 0:
            current_index = next((i for i, path in enumerate(images.values()) if str(path) == last_path), -1)
        step = -1 if operation == "previous" else 1
        if current_index < 0 and step < 0:
            current_index = 0
        index = (current_index + step) % len(candidates)
        resolved, target = candidates[index]
        return target, resolved == current

    if order == "random":
        alternatives = [(resolved, path) for resolved, path in candidates if resolved != current]
        resolved, target = random.choice(alternatives or candidates)
        return target, resolved == current

    index = 0
    if operation != "save":
        # Keep the sequence going after a manual or theme-driven change.
        # A new Shell instance can resume from Omarchy's current background.
        if last_path:
            previous = next((i for i, path in enumerate(images.values()) if str(path) == last_path), -1)
        else:
            previous = next((i for i, path in enumerate(images) if path == current), -1)
        index = (previous + 1) % len(candidates)
        if candidates[index][0] == current and len(candidates) > 1:
            index = (index + 1) % len(candidates)
    resolved, target = candidates[index]
    return target, resolved == current


def apply(settings_path, settings, operation, last_path):
    single = settings["mode"] == "single"
    selected = Path(settings["image"] if single else settings["directory"])
    result = {"saved": False, "error": "", "path": ""}
    if single and not is_image(selected):
        return {**result, "error": "image"}

    if operation in ("save", "save-only"):
        try:
            save_settings(settings_path, settings)
            result["saved"] = True
        except OSError:
            return {**result, "error": "save"}

    if operation == "save-only":
        return result

    if single:
        target = selected
    else:
        try:
            target, already_applied = rotation_image(selected, operation, last_path, settings.get("order"))
        except OSError:
            return {**result, "error": "directory"}
        if target is None:
            return {**result, "error": "empty"}
        if already_applied:
            return {**result, "path": str(target)}

    try:
        subprocess.run(["omarchy", "theme", "bg", "set", str(target)],
                       check=True, timeout=15, stdout=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return {**result, "error": "apply"}
    return {**result, "path": str(target)}


if __name__ == "__main__":
    settings_path, config, operation, last_path = sys.argv[1:]
    print(json.dumps(apply(Path(settings_path), json.loads(config), operation, last_path)))
