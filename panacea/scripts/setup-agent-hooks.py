#!/usr/bin/env python3
"""Add Panacea approval hooks without replacing existing agent settings."""
import json
import os
from pathlib import Path
import shlex
import tempfile

home = Path.home()
config = Path(os.environ.get('XDG_CONFIG_HOME', home / '.config'))
script = config / 'panacea/scripts/agent-approval.py'

def update(path, agent):
    if not path.parent.is_dir():
        return
    try:
        data = json.loads(path.read_text()) if path.exists() else {}
        entries = data.setdefault('hooks', {}).setdefault('PermissionRequest', [])
        command = '/usr/bin/python3 ' + shlex.quote(str(script)) + ' ' + agent
        if any(command == hook.get('command') for group in entries for hook in group.get('hooks', [])):
            return
        entries.append({'hooks': [{'type': 'command', 'command': command, 'timeout': 40}]})
        with tempfile.NamedTemporaryFile('w', dir=path.parent, delete=False, encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
            temp = Path(f.name)
        os.chmod(temp, 0o600)
        os.replace(temp, path)
    except (OSError, ValueError, TypeError, AttributeError) as error:
        print(f'Panacea: could not configure {agent} approval hooks: {error}')

update(home / '.claude/settings.json', 'Claude')
update(Path(os.environ.get('CODEX_HOME', home / '.codex')) / 'hooks.json', 'Codex')
