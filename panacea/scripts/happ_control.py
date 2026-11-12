#!/usr/bin/env python3
"""Control Happ through its existing tray action; never modify its profiles."""
import json
import subprocess
import time


def bus(*args):
    result = subprocess.run(['busctl', '--user', '--json=short', *args],
                            text=True, capture_output=True, timeout=3, check=True)
    return json.loads(result.stdout)['data'] if result.stdout.strip() else None


def property_value(owner, path, interface, name):
    return bus('get-property', owner, path, interface, name)


def menu_state(owner, path, layout):
    actions = {}
    transition = False
    for variant in layout[2]:
        node = variant['data']
        props = {key: value['data'] for key, value in node[1].items()}
        label = str(props.get('label', '')).replace('&', '').strip().casefold()
        if props.get('visible', True) is False:
            continue
        if label in ('disconnect', 'отключить', 'отключиться'):
            if props.get('enabled', True): actions['down'] = node[0]
            else: transition = True
        elif label in ('connect', 'подключить', 'подключиться'):
            if props.get('enabled', True): actions['up'] = node[0]
            else: transition = True
        elif label.startswith(('connecting', 'disconnecting', 'подключение', 'отключение')):
            transition = True
    state = 'busy' if transition else ('connected' if 'down' in actions else 'disconnected' if 'up' in actions else 'unknown')
    return {'clientState': state, '_owner': owner, '_menu': path, '_actions': actions}


def status():
    items = property_value('org.kde.StatusNotifierWatcher', '/StatusNotifierWatcher',
                           'org.kde.StatusNotifierWatcher', 'RegisteredStatusNotifierItems')
    for item in items:
        owner, separator, tail = item.partition('/')
        path = '/' + tail if separator else '/StatusNotifierItem'
        try:
            identity = property_value(owner, path, 'org.kde.StatusNotifierItem', 'Id')
            if str(identity).casefold() != 'happ': continue
            menu = property_value(owner, path, 'org.kde.StatusNotifierItem', 'Menu')
            data = bus('call', owner, menu, 'com.canonical.dbusmenu', 'GetLayout', 'iias', '0', '1', '2', 'label', 'enabled')
            return menu_state(owner, menu, data[1])
        except (OSError, ValueError, KeyError, subprocess.SubprocessError):
            continue
    return {'clientState': 'unavailable'}


def public(state):
    return {key: value for key, value in state.items() if not key.startswith('_')}


def toggle():
    current = status()
    state = current['clientState']
    if state not in ('connected', 'disconnected'):
        raise ValueError('Happ: connection state is unavailable or changing. Open Happ and select a server.')
    action = 'down' if state == 'connected' else 'up'
    action_id = current['_actions'][action]
    bus('call', current['_owner'], current['_menu'], 'com.canonical.dbusmenu', 'Event',
        'isvu', str(action_id), 'clicked', 's', '', str(int(time.time()) & 0xffffffff))
    desired = 'connected' if action == 'up' else 'disconnected'
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        result = status()
        if result['clientState'] == desired:
            return {'ok': True, 'action': action, **public(result)}
        if result['clientState'] == 'unavailable':
            raise ValueError('Happ closed before confirming the connection state.')
        time.sleep(0.15)
    raise TimeoutError('Happ did not confirm the requested connection state within 30 seconds. Check Happ for an error.')
