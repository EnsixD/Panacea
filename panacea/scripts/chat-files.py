#!/usr/bin/env python3
import json, pathlib, sys
try:
    path = pathlib.Path(sys.argv[1]).expanduser().resolve()
    items = []
    for entry in path.iterdir():
        if entry.name.startswith('.'): continue
        try: isdir = entry.is_dir()
        except OSError: continue
        items.append({'name':entry.name, 'path':str(entry), 'directory':isdir})
    items.sort(key=lambda item: (not item['directory'], item['name'].casefold()))
    print(json.dumps({'path':str(path),'items':items[:2000]}, ensure_ascii=False))
except (OSError, IndexError) as e:
    print(json.dumps({'error':str(e)},ensure_ascii=False))
