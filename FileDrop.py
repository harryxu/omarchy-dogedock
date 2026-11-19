import json
import sys
from urllib.parse import urlsplit

from gi.repository import Gio, GioUnix


def inspect_files(uris):
    files = []
    for uri in uris:
        parts = urlsplit(uri)
        if parts.scheme != "file" or parts.netloc.lower() not in ("", "localhost"):
            return []
        file = Gio.File.new_for_uri(uri)
        file_type = file.query_file_type(Gio.FileQueryInfoFlags.NONE)
        if file_type not in (Gio.FileType.REGULAR, Gio.FileType.DIRECTORY):
            return []
        files.append(file.get_uri())
    return files


def accepts_drop_arguments(app_id):
    try:
        app = GioUnix.DesktopAppInfo.new(app_id + ".desktop")
    except TypeError:
        # PyGObject raises when the desktop ID cannot be resolved.
        return False
    return app.supports_files() or app.supports_uris() or app.get_boolean("DBusActivatable")


if __name__ == "__main__":
    request = json.load(sys.stdin.buffer)
    app_ids = request["appIds"]
    uris = inspect_files(request["uris"])
    matches = [app_id for app_id in app_ids if uris and accepts_drop_arguments(app_id)]
    print(json.dumps({"uris": uris, "appIds": matches}))
