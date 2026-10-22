#!/usr/bin/env python3
"""Read/control the PulseAudio streams also controlled by deej."""
import json
import math
import os
import re
from pathlib import Path

import yaml
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True, timeout=2).strip()


def selected():
    media = json.loads(run('eww', 'get', 'media'))
    requested = run('eww', 'get', 'selected-player')
    # A click takes effect before the next metadata snapshot arrives.
    return requested if requested in media.get('players', []) else media.get('player', '')


def identity(player):
    key = player.lower().split('.')[0]
    # Chromium derivatives expose a generic MPRIS name with their browser PID.
    instance = re.search(r'\.instance(\d+)$', player)
    if instance:
        try:
            key = Path(os.readlink(f'/proc/{instance[1]}/exe')).name.lower()
        except OSError:
            pass
    return key


def streams(player):
    key = identity(player)
    if not key:
        return []
    entries = json.loads(run('pactl', '--format=json', 'list', 'sink-inputs'))
    return [s for s in entries if key in {
        str(s.get('properties', {}).get('application.name', '')).lower(),
        os.path.basename(str(s.get('properties', {}).get('application.process.binary', ''))).lower(),
        str(s.get('properties', {}).get('application.id', '')).lower(),
    }]


def description(player):
    key = identity(player)
    names = {'helium': 'Browser · Helium', 'chromium': 'Browser · Chromium',
             'firefox': 'Browser · Firefox', 'chrome': 'Browser · Chrome',
             'spotify': 'Spotify'}
    label = names.get(key, key or 'No player connected')
    tooltip = f'{label} · app volume'
    try:
        config = yaml.safe_load(Path.home().joinpath('.config/deej/config.yaml').read_text())
        for slider, apps in config.get('slider_mapping', {}).items():
            apps = apps if isinstance(apps, list) else [apps]
            if key and key in [str(app).lower() for app in apps]:
                tooltip = f'{label} · deej slider {int(slider) + 1}'
                break
    except (OSError, ValueError, AttributeError, yaml.YAMLError):
        pass
    return label, tooltip


def percent(item):
    values = [v['value'] for v in item['volume'].values()]
    return round(sum(values) / len(values) / 65536 * 100)


def main():
    if len(sys.argv) > 1:
        value = float(sys.argv[1])
        if not math.isfinite(value) or not 0 <= value <= 100:
            raise ValueError('Volume must be between 0 and 100')
        for stream in streams(selected()):
            run('pactl', 'set-sink-input-volume', str(int(stream['index'])), f'{value}%')
        return
    result = {'available': False, 'player': '', 'volume': 0, 'muted': False,
              'label': 'No player connected', 'control_label': 'Player', 'tooltip': 'Player volume'}
    try:
        player = selected()
        label, tooltip = description(player)
        result.update(player=player, label=label, tooltip=tooltip)
        matches = streams(player)
        if matches:
            result = {'available': True, 'player': player, 'label': label, 'tooltip': tooltip,
                      'volume': percent(matches[0]),
                      'muted': all(s.get('mute', False) for s in matches)}
    except (subprocess.SubprocessError, OSError, ValueError, KeyError):
        pass
    label = result['label']
    result['control_label'] = 'Browser' if label.startswith('Browser · ') else (label if result['player'] else 'Player')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
