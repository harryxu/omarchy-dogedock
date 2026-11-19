"""Copy local files dropped on a Folders icon."""

import json
import os
import sys

from gi.repository import Gio, GLib


def copy_files(directory, uris):
    destination = Gio.File.new_for_path(directory)
    failed = False
    for uri in uris:
        try:
            path, hostname = GLib.filename_from_uri(uri)
            if hostname and hostname.lower() != "localhost":
                raise ValueError("Only local files can be copied.")
            if os.path.samefile(os.path.dirname(path), directory):
                continue
            source = Gio.File.new_for_path(path)
            target = destination.get_child(source.get_basename())
            source.copy(target, Gio.FileCopyFlags.NOFOLLOW_SYMLINKS)
        except (GLib.Error, OSError, ValueError):
            failed = True
    return int(failed)


if __name__ == "__main__":
    request = json.load(sys.stdin.buffer)
    sys.exit(copy_files(request["directory"], request["uris"]))
