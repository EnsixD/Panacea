#!/usr/bin/env python3
"""Translate Panacea's static UI text and keep a per-locale cache.

Only strings passed to tr() are sent. Runtime values such as SSIDs, window
titles, and notification bodies are never part of the translation catalog.
"""

import json
import os
from pathlib import Path
import re
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


SOURCE = Path(__file__).resolve().parent.parent
CONFIG = Path.home() / ".config" / "panacea"
DEFAULT_SERVERS = ("https://translate.fedilab.app", "https://translate.cutie.dating")
CALL = re.compile(r'\.tr\(\s*("(?:\\.|[^"\\])*")')


def catalog():
    texts = set()
    paths = list(SOURCE.rglob("*.qml")) + [SOURCE.parent / "sddm" / "panacea" / "Main.qml"]
    for path in paths:
        if not path.is_file():
            continue
        if path.name == "Translations.qml":
            continue
        for match in CALL.finditer(path.read_text(encoding="utf-8")):
            try:
                value = json.loads(match.group(1))
            except json.JSONDecodeError:
                continue
            if value.strip():
                texts.add(value)
    return sorted(texts)


def target_code(locale_id):
    if not re.fullmatch(r"[A-Za-z]{2,3}(?:_[A-Za-z]{2})?", locale_id):
        raise ValueError("Invalid language code")
    if locale_id.lower() == "pt_br":
        return "pb"
    if locale_id.lower() == "zh_tw":
        return "zt"
    return locale_id.split("_", 1)[0].lower()


def servers(settings):
    configured = str(settings.get("translationUrl", "")).strip().rstrip("/")
    if configured:
        if not configured.startswith("https://") and not re.match(r"http://(localhost|127\.0\.0\.1)(:\d+)?$", configured):
            raise ValueError("Translation server must use HTTPS or localhost")
        return (configured,)
    if settings.get("translationApiKey"):
        return ("https://libretranslate.com",)
    return DEFAULT_SERVERS


def translate_batch(base_url, api_key, values, source, target):
    body = {"q": values, "source": source, "target": target, "format": "text"}
    if api_key:
        body["api_key"] = api_key
    payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
    request = Request(base_url + "/translate", data=payload,
                      headers={"Content-Type": "application/json", "User-Agent": "Panacea/1.0"})
    with urlopen(request, timeout=12) as response:
        result = json.load(response).get("translatedText")
    if isinstance(result, str) and len(values) == 1:
        result = [result]
    if not isinstance(result, list) or len(result) != len(values) or not all(isinstance(x, str) for x in result):
        raise ValueError("Translation server returned an unexpected response")
    return result


def write_cache(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, name = tempfile.mkstemp(prefix=".translations-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(data, stream, ensure_ascii=False, indent=2, sort_keys=True)
            stream.write("\n")
        os.chmod(name, 0o600)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main(locale_id):
    target = target_code(locale_id)
    if target in ("en", "ru"):
        return 0
    settings_file = CONFIG / "settings.json"
    settings = json.loads(settings_file.read_text(encoding="utf-8")) if settings_file.exists() else {}
    endpoint_list = servers(settings)
    api_key = str(settings.get("translationApiKey", ""))
    cache = CONFIG / "translations" / (locale_id + ".json")
    try:
        translated = json.loads(cache.read_text(encoding="utf-8"))
        if not isinstance(translated, dict):
            translated = {}
    except (OSError, ValueError):
        translated = {}

    pending = {"ru": [], "en": []}
    for value in catalog():
        if value not in translated:
            source = "ru" if re.search(r"[А-Яа-яЁё]", value) else "en"
            pending[source].append(value)

    for source, phrases in pending.items():
        for offset in range(0, len(phrases), 16):
            batch = phrases[offset:offset + 16]
            last_error = None
            for endpoint in endpoint_list:
                try:
                    results = translate_batch(endpoint, api_key, batch, source, target)
                    translated.update(zip(batch, results))
                    write_cache(cache, translated)
                    time.sleep(0.15)
                    last_error = None
                    break
                except (HTTPError, URLError, TimeoutError, ValueError, OSError) as error:
                    last_error = error
            if last_error is not None:
                print(f"Translation unavailable: {last_error}", file=sys.stderr)
                return 1
    print(f"Translated {len(translated)} interface strings for {locale_id}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: translate_ui.py LOCALE", file=sys.stderr)
        raise SystemExit(2)
    try:
        raise SystemExit(main(sys.argv[1]))
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
