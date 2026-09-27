#!/usr/bin/env python3
"""Publish the selected Panacea UI language for the SDDM theme."""

import json
from pathlib import Path
import re
import sys
import tempfile
import os


LABELS = {
    "Пароль": "Password",
    "Неверный пароль": "Wrong password",
    "Сон": "Sleep",
    "Перезагрузка": "Restart",
    "Выключить": "Shut down",
}


def main(locale_id, target=None, cache_file=None):
    if not re.fullmatch(r"[A-Za-z]{2,3}(?:_[A-Za-z]{2})?", locale_id):
        return 1
    target = Path(target) if target is not None else Path("/var/lib/panacea/locale.qml")
    if not target.parent.is_dir() or not os.access(target.parent, os.W_OK):
        return 0
    cache_file = Path(cache_file) if cache_file is not None else Path.home() / ".config" / "panacea" / "translations" / (locale_id + ".json")
    try:
        cache = json.loads(cache_file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        cache = {}
    language = locale_id.split("_", 1)[0]
    labels = {key: key if language == "ru" else LABELS[key] if language == "en"
              else cache.get(key, LABELS[key]) for key in LABELS}
    body = "import QtQuick 2.15\nQtObject {\n"
    body += "    property string lang: " + json.dumps(locale_id) + "\n"
    body += "    property var translations: (" + json.dumps(labels, ensure_ascii=False) + ")\n}\n"
    descriptor, path = tempfile.mkstemp(prefix=".locale-", dir=target.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(body)
        os.chmod(path, 0o644)
        os.replace(path, target)
    finally:
        if os.path.exists(path):
            os.unlink(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1]) if len(sys.argv) == 2 else 2)
