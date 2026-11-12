#!/usr/bin/env python3
"""Ask through Panacea; a closed/expired notification leaves the original prompt intact."""
import html
import json
import os
from pathlib import Path
import subprocess
import sys

def agent_is_in_focused_window():
    # Only suppress when the focused window's process is an ancestor of this
    # exact hook. Another terminal with the same class must still get alerts.
    try:
        result = subprocess.run(['hyprctl', '-j', 'activewindow'], capture_output=True,
                                text=True, timeout=1, check=True)
        focused = int(json.loads(result.stdout).get('pid', 0))
        pid = os.getppid()
        while focused > 1 and pid > 1:
            if pid == focused:
                return True
            status = Path('/proc') / str(pid) / 'status'
            ppid = next(line for line in status.read_text().splitlines() if line.startswith('PPid:'))
            pid = int(ppid.split()[1])
    except (OSError, ValueError, StopIteration, subprocess.SubprocessError):
        pass
    return False

try:
    data = json.load(sys.stdin)
    if agent_is_in_focused_window():
        sys.exit(0)
    agent = sys.argv[1]
    tool = str(data.get('tool_name') or 'tool')
    details = data.get('tool_input') or {}
    if not isinstance(details, dict):
        details = {}
    text = str(details.get('command') or '')
    # Only offer a decision when the complete command fits on the card.
    # All other requests continue through the agent's normal approval UI.
    if tool not in ('Bash', 'shell_command', 'exec_command') or not text or len(text) > 75 or '\n' in text:
        sys.exit(0)
    body = html.escape(tool + ': ' + text)
    result = subprocess.run(['notify-send', '--app-name', 'Panacea ' + agent,
        '--icon', 'dialog-question', '--urgency', 'normal', '--expire-time', '30000',
        '--action=panacea-allow=Разрешить', '--action=panacea-deny=Отклонить',
        agent + ': требуется подтверждение', body],
        text=True, capture_output=True, timeout=35, check=False)
    choice = result.stdout.strip()
    if result.returncode == 0 and choice in ('panacea-allow', 'panacea-deny'):
        decision = {'behavior': 'allow' if choice == 'panacea-allow' else 'deny'}
        print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PermissionRequest', 'decision': decision}}))
except (ValueError, OSError, subprocess.TimeoutExpired):
    pass
