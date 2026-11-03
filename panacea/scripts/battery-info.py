#!/usr/bin/env python3
"""Collect battery details and a bounded, local charge history."""
import json
import os
import pathlib
import tempfile
import time

root = pathlib.Path(os.environ.get('PANACEA_POWER_SUPPLY', '/sys/class/power_supply'))
battery = next((p for p in sorted(root.glob('*')) if (p / 'type').exists() and (p / 'type').read_text().strip() == 'Battery'), None)
if battery is None:
    print('{}')
    raise SystemExit

def number(name):
    try:
        return int((battery / name).read_text().strip())
    except (OSError, ValueError):
        return None

state = pathlib.Path(os.environ.get('XDG_STATE_HOME', pathlib.Path.home() / '.local/state')) / 'panacea'
file = state / 'battery-history.json'
now = int(time.time())
try:
    history = json.loads(file.read_text())
    if not isinstance(history, list):
        history = []
except (OSError, ValueError):
    history = []
history = [x for x in history if isinstance(x, list) and len(x) == 2 and isinstance(x[0], (int, float)) and isinstance(x[1], (int, float)) and now - 86400 <= x[0] <= now]
percent = number('capacity')
if percent is not None and 0 <= percent <= 100 and (not history or now - history[-1][0] >= 300):
    history.append([now, percent])
    try:
        state.mkdir(mode=0o700, parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile('w', dir=state, delete=False) as f:
            json.dump(history[-288:], f)
            temp = f.name
        os.replace(temp, file)
    except OSError:
        pass
print(json.dumps({'name': battery.name, 'cycle': number('cycle_count'), 'start': number('charge_control_start_threshold'), 'end': number('charge_control_end_threshold'), 'history': history[-288:]}, ensure_ascii=False))
