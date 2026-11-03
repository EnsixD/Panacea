#!/usr/bin/env python3
"""Non-destructive file actions for the island."""
import os
import pathlib
import sys
import tarfile
import zipfile

operation = sys.argv[1]
sources = sys.argv[2:]
if not sources:
    raise SystemExit("No files")

def unused(path):
    candidate = path
    i = 1
    while candidate.exists():
        candidate = path.with_name(f'{path.stem} ({i}){path.suffix}')
        i += 1
    return candidate

for source in sources:
    path = pathlib.Path(source)
    if not path.is_file():
        raise SystemExit('File not found')
    if operation == 'compress':
        from PIL import Image, ImageOps
        target = unused(path.with_name(path.stem + '-compressed.webp'))
        with Image.open(path) as image:
            image = ImageOps.exif_transpose(image)
            image.save(target, 'WEBP', quality=82, method=5)
        print(target)
    elif operation == 'extract':
        name = path.name
        for ext in ('.tar.gz', '.tar.xz', '.tar.bz2', '.zip', '.tar', '.tgz'):
            if name.lower().endswith(ext):
                name = name[:-len(ext)]
                break
        target = unused(path.parent / (name + '-extracted'))
        target.mkdir()
        try:
            if zipfile.is_zipfile(path):
                with zipfile.ZipFile(path) as archive:
                    for info in archive.infolist():
                        rel = pathlib.PurePosixPath(info.filename)
                        if rel.is_absolute() or '..' in rel.parts or (info.external_attr >> 16) & 0o170000 == 0o120000:
                            raise ValueError('Unsafe archive entry')
                    archive.extractall(target)
            elif tarfile.is_tarfile(path):
                with tarfile.open(path) as archive:
                    archive.extractall(target, filter='data')
            else:
                raise ValueError('Unsupported archive format')
        except Exception:
            # Keep the directory rather than deleting potentially user-modified data.
            raise
        print(target)
    else:
        raise SystemExit('Unsupported action')
