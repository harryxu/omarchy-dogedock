#!/usr/bin/env python3
"""Replace commands that would touch the desktop or system Trash."""

import json
import os
from pathlib import Path
import sys
import time
from urllib.parse import unquote, urlsplit


root = Path(os.environ["DOGEDOCK_TEST_ROOT"])
command = Path(sys.argv[0]).name
args = sys.argv[1:]
count = root / "trash-count"

if command == "omarchy-shell":
    sys.exit(0)

if command == "gio":
    if args == ["info", "-a", "trash::item-count", "trash:///"]:
        print(f"  trash::item-count: {count.read_text()}")
        sys.exit(0)
    if args == ["monitor", "--dir=trash:///"]:
        while True:
            time.sleep(1)
    folder = len(args) == 2 and args[0] == "open" and args[1].startswith("file:///") and (
        Path(unquote(urlsplit(args[1]).path)).parent == root
    )
    if not folder and args not in (["open", "trash:///"], ["trash", "--empty"]) and args[:2] != ["trash", "--"]:
        sys.exit(f"Unexpected gio command: {args}")

with (root / "calls.jsonl").open("a", encoding="utf-8") as calls:
    calls.write(json.dumps([command, *args]) + "\n")

if command == "gio" and args == ["trash", "--empty"]:
    count.write_text("0")
elif command == "gio" and args[:2] == ["trash", "--"]:
    count.write_text("1")
    if "file:///example/failed" in args:
        sys.exit("Permission denied: <failed>")
