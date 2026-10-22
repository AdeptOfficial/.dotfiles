#!/usr/bin/env python3
"""Bounded Hyprland snapshot for the EWW workspace tab (no shell execution)."""
import concurrent.futures
import json
import subprocess


def query(name):
    result = subprocess.run(['hyprctl', name, '-j'], capture_output=True,
                            text=True, check=True, timeout=1)
    return json.loads(result.stdout)


def build(monitors, workspaces, clients, rules):
    monitors = sorted((m for m in monitors if not m.get('disabled')),
                      key=lambda m: (m.get('x', 0), m.get('y', 0)))
    by_name = {m['name']: m for m in monitors}
    assigned = {}
    for rule in rules:
        key = rule.get('workspaceString', '')
        if not rule.get('enabled', True) or not key.isdecimal() or int(key) <= 0:
            continue
        target = rule.get('monitor', '')
        for m in monitors:
            if target == m['name'] or (target.startswith('desc:') and
                                      m.get('description', '').startswith(target[5:])):
                assigned[int(key)] = m['name']
                break
    live = {w['id']: w for w in workspaces if w['id'] > 0}
    assigned.update({i: w['monitor'] for i, w in live.items() if w['monitor'] in by_name})
    windows = {}
    for c in clients:
        if c.get('mapped') and not c.get('hidden'):
            windows.setdefault(c.get('workspace', {}).get('id'), []).append(c)
    groups = []
    total = 0
    for m in monitors:
        cards = []
        for wid in sorted(i for i, name in assigned.items() if name == m['name']):
            entries = sorted(windows.get(wid, []), key=lambda c: c.get('focusHistoryID', 999))
            visible = m.get('activeWorkspace', {}).get('id') == wid
            active = visible and m.get('focused', False)
            apps = []
            wins = []
            for c in entries:
                app = c.get('class') or c.get('initialClass') or 'Application'
                if 'ghostty' in app.lower(): app = 'Terminal'
                elif app.lower() == 'steam': app = 'Steam'
                else: app = app.split('.')[-1]
                if app not in apps: apps.append(app)
                address = c.get('address', '')
                # Only compositor addresses can reach the command argument.
                if address.startswith('0x') and all(x in '0123456789abcdefABCDEF' for x in address[2:]) and len(address) > 2:
                    wins.append({'address': address, 'title': c.get('title') or app, 'app': app})
            count = len(entries)
            total += count
            cards.append({'id': wid, 'number': f'{wid:02}',
                          'state': 'ACTIVE' if active else 'VISIBLE' if visible else '',
                          'css': 'workspace-card ' + ('focused' if active else 'visible' if visible else 'empty' if not count else 'occupied'),
                          'apps': ' · '.join(('󰆍 ' if app == 'Terminal' else '󰓓 ' if app == 'Steam' else '󰈙 ') + app for app in apps) if apps else 'Empty workspace',
                          'title': entries[0].get('title', '') if entries else 'Ready for a window',
                          'count': f'{count} window' + ('' if count == 1 else 's'),
                          'windows': wins})
        groups.append({'name': m.get('model') or m['name'], 'port': m['name'],
                       'detail': 'Focused monitor' if m.get('focused') else 'Other monitor',
                       'rows': [cards[i:i+3] for i in range(0, len(cards), 3)]})
    return {'groups': groups, 'summary': f'{len(assigned)} workspaces · {total} windows', 'error': ''}


def main():
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            data = list(pool.map(query, ['monitors', 'workspaces', 'clients', 'workspacerules']))
        result = build(*data)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        result = {'groups': [], 'summary': 'Unavailable',
                  'error': 'Cannot reach Hyprland. Retrying shortly…'}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
