#!/usr/bin/env python3
import os, pathlib, subprocess, tempfile
try:
    types = subprocess.run(['wl-paste','--list-types'],capture_output=True,text=True,timeout=2,check=True).stdout.splitlines()
    mime = next((t for t in ('image/png','image/jpeg','image/webp') if t in types), None)
    if mime:
        image = subprocess.run(['wl-paste','--no-newline','--type',mime],capture_output=True,timeout=5,check=True).stdout
        if len(image) > 5*1024*1024: raise ValueError('image too large')
        folder = pathlib.Path(os.environ.get('XDG_CACHE_HOME', pathlib.Path.home()/'.cache'))/'panacea/chat-attachments'
        folder.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=folder, suffix={'image/png':'.png','image/jpeg':'.jpg','image/webp':'.webp'}[mime],delete=False) as f:
            f.write(image); print(f.name)
except (OSError, ValueError, subprocess.SubprocessError): pass
