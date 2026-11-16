#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

node tests/dock_model.test.js
/usr/bin/python tests/test_file_drop.py
/usr/bin/python tests/run_extensions.py
omarchy plugin validate .
