"""Exercise the file-drop CLI with real files and isolated Gio desktop entries."""

import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "FileDrop.py"


class FileDropTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="doge-file-drop-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.env = os.environ | {
            "XDG_DATA_HOME": str(self.root / "data"),
            "XDG_DATA_DIRS": str(self.root / "system-data"),
        }
        system_data = self.root / "system-data"
        system_data.mkdir()
        (system_data / "mime").symlink_to("/usr/share/mime", target_is_directory=True)
        self.applications = self.root / "data/applications"
        self.applications.mkdir(parents=True)
        self.text = self.root / "résumé with spaces.txt"
        self.text.write_text("Example text\n", encoding="utf-8")
        self.image = self.root / "art.png"
        self.image.write_bytes(base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jM1sAAAAASUVORK5CYII="
        ))

    def desktop_entry(self, name, mime_types, command="true %F", extra=""):
        (self.applications / f"{name}.desktop").write_text(
            f"[Desktop Entry]\nType=Application\nName={name}\nExec={command}\n"
            f"MimeType={mime_types};\n{extra}", encoding="utf-8"
        )

    def probe(self, app_ids, *uris):
        result = subprocess.run(
            [sys.executable, str(HELPER)],
            input=json.dumps({"appIds": app_ids, "uris": uris}),
            env=self.env, check=True, capture_output=True, text=True, timeout=10,
        )
        return json.loads(result.stdout)

    def test_a_batch_requires_support_for_each_type_and_a_file_aware_launcher(self):
        self.desktop_entry("text", "text/plain")
        self.desktop_entry("both", "text/plain;image/png", "true %U")
        self.desktop_entry("no-file-args", "text/plain;image/png", "true")
        self.desktop_entry("dbus", "text/plain;image/png", "true", "DBusActivatable=true\n")
        uris = [self.text.as_uri(), self.image.as_uri()]
        result = self.probe(["text", "missing", "both", "no-file-args", "dbus"], *uris)
        self.assertEqual(result, {"uris": uris, "appIds": ["both", "dbus"]})

    def test_nonlocal_missing_and_directory_items_reject_the_whole_batch(self):
        self.desktop_entry("text", "text/plain")
        for invalid in (
            "https://example.invalid/document.txt",
            "file://another-host/tmp/document.txt",
            (self.root / "missing").as_uri(),
            self.root.as_uri(),
        ):
            with self.subTest(uri=invalid):
                self.assertEqual(
                    self.probe(["text"], self.text.as_uri(), invalid),
                    {"uris": [], "appIds": []},
                )

    def test_localhost_uri_is_returned_in_canonical_file_form(self):
        self.desktop_entry("text", "text/plain")
        uri = self.text.as_uri()
        self.assertEqual(
            self.probe(["text"], uri.replace("file://", "file://localhost", 1)),
            {"uris": [uri], "appIds": ["text"]},
        )


if __name__ == "__main__":
    unittest.main()
