"""List a directory for the Folders menu."""

import json
import os
import sys


def entries_for(directory):
    entries = []
    with os.scandir(directory) as children:
        for child in children:
            try:
                is_directory = child.is_dir()
                if is_directory or child.is_file():
                    entries.append({"name": child.name, "directory": is_directory})
            except OSError:
                continue
    return sorted(entries, key=lambda entry: (not entry["directory"], entry["name"].casefold(), entry["name"]))


if __name__ == "__main__":
    try:
        print(json.dumps(entries_for(sys.argv[1])))
    except OSError as error:
        sys.exit(str(error))
