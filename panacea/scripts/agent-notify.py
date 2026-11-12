#!/usr/bin/env python3
"""Forward agent attention requests to the desktop notification server."""
import json
import os
import subprocess
import sys

try:
    event = json.load(sys.stdin)
except (ValueError, OSError):
    event = {}
agent = sys.argv[1] if len(sys.argv) > 1 else "Agent"
if agent == "Codex":
    tool = str(event.get("tool_name") or "")
    details = event.get("tool_input") or {}
    if not isinstance(details, dict):
        details = {}
    body = str(details.get("description") or details.get("command") or tool or "Требуется подтверждение")
    title = "Codex: требуется подтверждение"
else:
    title = "Claude Code: требуется внимание"
    body = str(event.get("message") or "Откройте Claude Code, чтобы ответить")
body = " ".join(body.split())[:300]
try:
    subprocess.run(["notify-send", "--app-name", agent, "--icon", "dialog-question",
                    "--urgency", "normal", title, body],
                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=3, check=False)
except (OSError, subprocess.TimeoutExpired):
    pass
