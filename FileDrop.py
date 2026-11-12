import json
import sys
from urllib.parse import urlsplit

from gi.repository import Gio, GioUnix, GLib


def inspect_files(uris):
    files = []
    content_types = set()
    for uri in uris:
        parts = urlsplit(uri)
        if parts.scheme != "file" or parts.netloc.lower() not in ("", "localhost"):
            return [], set()
        file = Gio.File.new_for_uri(uri)
        try:
            info = file.query_info("standard::type,standard::content-type", Gio.FileQueryInfoFlags.NONE)
        except GLib.Error:
            return [], set()
        content_type = info.get_content_type()
        if info.get_file_type() != Gio.FileType.REGULAR or not content_type:
            return [], set()
        files.append(file.get_uri())
        content_types.add(content_type)
    return files, content_types


def supports_types(app_id, content_types):
    try:
        app = GioUnix.DesktopAppInfo.new(app_id + ".desktop")
    except TypeError:
        # PyGObject raises when the desktop ID cannot be resolved.
        return False
    if not (app.supports_files() or app.supports_uris() or app.get_boolean("DBusActivatable")):
        return False
    declared = [Gio.content_type_from_mime_type(mime) for mime in app.get_supported_types()]
    return all(
        any(Gio.content_type_is_a(actual, supported) for supported in declared)
        for actual in content_types
    )


if __name__ == "__main__":
    app_ids = json.loads(sys.argv[1])
    uris, content_types = inspect_files(sys.argv[2:])
    matches = [app_id for app_id in app_ids if uris and supports_types(app_id, content_types)]
    print(json.dumps({"uris": uris, "appIds": matches}))
