"""Exercise the file-drop CLI with real files and isolated Gio desktop entries."""

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
        self.applications = self.root / "data/applications"
        self.applications.mkdir(parents=True)
        self.text = self.root / "résumé with spaces.txt"
        self.text.write_text("Example text\n", encoding="utf-8")

    def desktop_entry(self, name, command="true %F", extra=""):
        (self.applications / f"{name}.desktop").write_text(
            f"[Desktop Entry]\nType=Application\nName={name}\nExec={command}\n{extra}",
            encoding="utf-8",
        )

    def probe(self, app_ids, *uris):
        result = subprocess.run(
            [sys.executable, str(HELPER), json.dumps(app_ids), *uris],
            env=self.env, check=True, capture_output=True, text=True, timeout=10,
        )
        return json.loads(result.stdout)

    def test_drop_checks_launch_arguments_without_filtering_mime_types(self):
        directory = self.root / "project #1"
        directory.mkdir()
        self.desktop_entry("single-path", "true %f")
        self.desktop_entry("multiple-paths", "true %F")
        self.desktop_entry("single-uri", "true %u")
        self.desktop_entry("zed-like", "true %U", "MimeType=text/plain;\n")
        self.desktop_entry("dbus", "true", "DBusActivatable=true\n")
        self.desktop_entry("no-file-args", "true", "MimeType=inode/directory;text/plain;\n")
        accepted = ["single-path", "multiple-paths", "single-uri", "zed-like", "dbus"]
        app_ids = accepted + ["no-file-args", "missing"]

        for uris in ([directory.as_uri()], [self.text.as_uri(), directory.as_uri()]):
            with self.subTest(uris=uris):
                self.assertEqual(self.probe(app_ids, *uris), {"uris": uris, "appIds": accepted})

    def test_nonlocal_missing_and_special_items_reject_the_whole_batch(self):
        self.desktop_entry("text")
        pipe = self.root / "pipe"
        os.mkfifo(pipe)
        for invalid in (
            "https://example.invalid/document.txt",
            "file://another-host/tmp/document.txt",
            (self.root / "missing").as_uri(),
            pipe.as_uri(),
        ):
            with self.subTest(uri=invalid):
                self.assertEqual(
                    self.probe(["text"], self.text.as_uri(), invalid),
                    {"uris": [], "appIds": []},
                )

    def test_localhost_uri_is_returned_in_canonical_file_form(self):
        self.desktop_entry("text")
        uri = self.text.as_uri()
        self.assertEqual(
            self.probe(["text"], uri.replace("file://", "file://localhost", 1)),
            {"uris": [uri], "appIds": ["text"]},
        )


if __name__ == "__main__":
    unittest.main()
