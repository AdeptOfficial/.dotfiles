#!/usr/bin/env python3
"""Build and validate Syna themes before an atomic Linux directory exchange."""
import argparse
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib

ROOT = Path.home() / '.config/themes'
SCRIPTS = Path.home() / '.local/bin/rice'
TOKEN = re.compile(r'{{\s*(\w+)\s*}}')


def run(argv, **kwargs):
    return subprocess.run(list(map(str, argv)), text=True, capture_output=True,
                          timeout=30, **kwargs)


def palette(path, override=None):
    data = tomllib.loads(path.read_text())
    if override is not None and override.exists():
        if override.is_symlink():
            raise ValueError('Palette override must not be a symlink')
        custom = tomllib.loads(override.read_text())
        unknown = set(custom) - (set(data) | {'border_top', 'border_bottom'})
        if unknown:
            raise ValueError('Unknown override colors: ' + ', '.join(sorted(unknown)))
        data.update(custom)
    required = ['accent', 'background', 'foreground', 'cursor',
                'selection_background', 'selection_foreground'] + [f'color{i}' for i in range(16)]
    for key in required:
        if not re.fullmatch(r'#[0-9a-fA-F]{6}', str(data.get(key, ''))):
            raise ValueError(f'{path.parent.name}: missing or invalid color {key}')
    data.setdefault('border_top', data['accent'])
    data.setdefault('border_bottom', data['foreground'])
    for key, value in list(data.items()):
        if not isinstance(value, str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
            raise ValueError(f'{path}: {key} must be a six-digit hex color')
        data[key + '_strip'] = value[1:]
        data[key + '_rgb'] = ','.join(str(int(value[i:i+2], 16)) for i in (1, 3, 5))
    return data


PROMPT_DEFAULTS = {'prompt_user': 'color4', 'prompt_host': 'color2', 'prompt_at': 'color2',
                   'prompt_directory': 'color6', 'prompt_success': 'color2',
                   'prompt_error': 'color1'}


def prompt_colors(name, colors, use_override=True):
    result = {key: colors[value] for key, value in PROMPT_DEFAULTS.items()}
    result['prompt_at'] = result['prompt_host']   # the @ follows the host colour unless a theme sets it
    path = ROOT / '.overrides' / (name + '.prompt.toml')
    if use_override and path.exists():
        if path.is_symlink(): raise ValueError('Prompt colors must not be a symlink')
        override = tomllib.loads(path.read_text())
        if set(override) - set(result): raise ValueError('Unknown prompt color')
        if any(not re.fullmatch(r'#[0-9a-fA-F]{6}', str(v)) for v in override.values()):
            raise ValueError('Prompt colors must be six-digit hex colors')
        result.update(override)
        if 'prompt_at' not in override:
            result['prompt_at'] = result['prompt_host']
    return result




NVIM_DEFAULTS = {'background': 'background', 'text': 'foreground', 'cursor': 'cursor',
                 'selection': 'selection_background', 'selection_text': 'selection_foreground',
                 'comment': 'color8', 'keyword': 'color5', 'string': 'color2',
                 'function': 'color4', 'number': 'color3', 'line_number': 'color8',
                 'error': 'color1', 'warning': 'color3'}

def nvim_colors(name, colors, use_override=True):
    result = {key: colors[source] for key, source in NVIM_DEFAULTS.items()}
    path = ROOT / '.overrides' / (name + '.nvim.toml')
    if use_override and path.exists():
        if path.is_symlink(): raise ValueError('Neovim colors must not be a symlink')
        data = tomllib.loads(path.read_text())
        if set(data) - set(result): raise ValueError('Unknown Neovim color')
        if any(not re.fullmatch(r'#[0-9a-fA-F]{6}', str(v)) for v in data.values()):
            raise ValueError('Neovim colors must be six-digit hex colors')
        result.update(data)
    return result


# border_motion: seconds per turn of the active border's gradient (0 = still). A turning border makes Hyprland render
# every frame at the refresh rate, also when borders are hidden; measured 2026-10-22 on the RTX desktop: within noise.
WINDOW_DEFAULTS = {'border_size': 2, 'rounding': 8, 'border_motion': 0}
WINDOW_MAXIMUM = {'border_size': 10, 'rounding': 40, 'border_motion': 60}

def window_settings(name, use_override=True):
    """Window shape and border motion: defaults, then the theme's own window.toml, then the user's override."""
    result = dict(WINDOW_DEFAULTS)
    paths = [ROOT / name / 'window.toml'] + ([ROOT / '.overrides' / (name + '.window.toml')] if use_override else [])
    for path in paths:
        if not path.exists():
            continue
        if path.is_symlink(): raise ValueError('Window settings must not be a symlink')
        data = tomllib.loads(path.read_text())
        if set(data) - set(result): raise ValueError('Unknown window setting')
        for key, value in data.items():
            maximum = WINDOW_MAXIMUM[key]
            if type(value) is not int or not 0 <= value <= maximum:
                raise ValueError(f'{key} must be an integer from 0 to {maximum}')
        result.update(data)
    return result

def window_config(settings):
    text = f"general {{\n    border_size = {settings['border_size']}\n}}\ndecoration {{\n    rounding = {settings['rounding']}\n}}\n"
    if settings['border_motion']:   # speed is in tenths of a second
        text += f"animations {{\n    animation = borderangle, 1, {settings['border_motion'] * 10}, linear, loop\n}}\n"
    return text


ICON_NAME = re.compile(r'[A-Za-z0-9][A-Za-z0-9._+-]{0,63}')
DEFAULT_ICONS = 'Yaru-blue'


def icon_themes():
    """Installed icon themes (not cursor-only themes): directories with an index.theme listing icon Directories."""
    found = set()
    for base in (Path('/usr/share/icons'), Path.home() / '.local/share/icons', Path.home() / '.icons'):
        for index in base.glob('*/index.theme') if base.is_dir() else []:
            try:
                text = index.read_text(errors='replace')
            except OSError:
                continue
            if re.search(r'^Directories\s*=\s*\S', text, re.M) and ICON_NAME.fullmatch(index.parent.name):
                found.add(index.parent.name)
    return sorted(found, key=str.casefold)


def theme_icons(name, use_override=True):
    """Icon theme for a theme: the user's override (.overrides/<name>.icons), else the theme's own icons.theme."""
    candidates = [ROOT / '.overrides' / (name + '.icons')] if use_override else []
    candidates.append(ROOT / name / 'icons.theme')
    for path in candidates:
        if path.is_file() and not path.is_symlink():
            value = path.read_text().strip()
            if not ICON_NAME.fullmatch(value):
                raise ValueError(f'Invalid icon theme name in {path.name}')
            return value
    return None


DEFAULT_CURSOR = 'Adwaita'


def cursor_themes():
    """Installed cursor themes: icon-theme directories that contain a cursors/ folder."""
    found = set()
    for base in (Path('/usr/share/icons'), Path.home() / '.local/share/icons', Path.home() / '.icons'):
        for cursors in base.glob('*/cursors') if base.is_dir() else []:
            if cursors.is_dir() and ICON_NAME.fullmatch(cursors.parent.name):
                found.add(cursors.parent.name)
    return sorted(found, key=str.casefold)


def theme_cursor(name, use_override=True):
    """Cursor theme for a theme: the user's override (.overrides/<name>.cursor), else the theme's cursor.theme."""
    candidates = [ROOT / '.overrides' / (name + '.cursor')] if use_override else []
    candidates.append(ROOT / name / 'cursor.theme')
    for path in candidates:
        if path.is_file() and not path.is_symlink():
            value = path.read_text().strip()
            if not ICON_NAME.fullmatch(value):
                raise ValueError(f'Invalid cursor theme name in {path.name}')
            return value
    return None


def window_config_lua(settings):
    # Integers are range-checked in window_settings().
    text = ("hl.config({\n"
            f"    general = {{ border_size = {settings['border_size']} }},\n"
            f"    decoration = {{ rounding = {settings['rounding']} }},\n"
            "})\n")
    if settings['border_motion']:
        text += ("hl.animation({ leaf = \"borderangle\", enabled = true, "
                 f"speed = {settings['border_motion'] * 10}, "
                 "bezier = \"linear\", style = \"loop\" })\n")
    return text


def render(template, colors):
    colors = dict(colors)
    for key, source in PROMPT_DEFAULTS.items():
        if source in colors: colors.setdefault(key, colors[source])
    def replace(match):
        if match[1] not in colors:
            raise ValueError(f'Unknown template color: {match[1]}')
        return colors[match[1]]
    result = TOKEN.sub(replace, template)
    if '{{' in result or '}}' in result:
        raise ValueError('Unresolved template placeholder')
    return result


def build(name, stage):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', name) or name in ('current', 'previous', 'templates', 'backgrounds', 'next-theme'):
        raise ValueError('Invalid theme name')
    source = ROOT / name
    if source.is_symlink() or (source / 'colors.toml').is_symlink():
        raise ValueError('Theme directory and palette must not be symlinks')
    override = ROOT / '.overrides' / (name + '.toml')
    colors = palette(source / 'colors.toml', override)
    colors.update(prompt_colors(name, colors))
    trust_file = ROOT / '.trusted-styles.json'
    trusted = json.loads(trust_file.read_text()) if trust_file.exists() else {}
    for item in source.iterdir():
        if item.is_symlink():
            continue
        if item.name == 'backgrounds' and item.is_dir():
            # Do not follow links from a downloaded theme into other directories.
            for base, dirs, files in os.walk(item, followlinks=False):
                dirs[:] = [d for d in dirs if not (Path(base) / d).is_symlink()]
                for filename in files:
                    image = Path(base) / filename
                    if image.is_symlink() or image.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp', '.avif'):
                        continue
                    target = stage / 'backgrounds' / image.relative_to(item)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(image, target)
        elif item.is_file() and item.name == 'colors.toml':
            shutil.copy2(item, stage / item.name)
        elif item.is_file() and item.name == 'light.mode':
            (stage / item.name).touch()
        elif item.is_file() and trusted.get(name, {}).get(item.name) == hashlib.sha256(item.read_bytes()).hexdigest():
            # Only pre-existing local styles reviewed at migration are trusted.
            shutil.copy2(item, stage / item.name)
    # Explicit per-theme files take precedence; templates fill missing files.
    for template in (ROOT / 'templates').glob('*.tpl'):
        target = stage / template.name.removesuffix('.tpl')
        if not target.exists() or override.exists() or target.name == 'starship.toml':
            target.write_text(render(template.read_text(), colors))
    (stage / 'neovim.json').write_text(json.dumps(nvim_colors(name, colors)))
    (stage / 'window-geometry.conf').write_text(window_config(window_settings(name)))
    (stage / 'window-geometry.lua').write_text(window_config_lua(window_settings(name)))
    for required in ('hyprland.conf', 'hyprland.lua', 'eww-colors.scss', 'fastfetch.jsonc'):
        if not (stage / required).is_file():
            raise ValueError(f'Missing generated file: {required}')
    icons = theme_icons(name)
    if icons:
        (stage / 'icons.theme').write_text(icons + '\n')
    cursor = theme_cursor(name)
    if cursor:
        (stage / 'cursor.theme').write_text(cursor + '\n')
    (stage / '.theme-name').write_text(name + '\n')
    # Explicit personal wallpaper selection survives switching away and back.
    preference = ROOT / '.overrides' / (name + '.wallpaper')
    if preference.is_file() and not preference.is_symlink():
        selected = Path(preference.read_text().strip())
        allowed = [source / 'backgrounds', ROOT / 'backgrounds' / name]
        if (selected.parent in allowed and selected.is_file() and not selected.is_symlink()
                and selected.suffix.lower() in ('.png', '.jpg', '.jpeg', '.webp', '.avif')):
            (stage / 'background').symlink_to(selected.resolve())
            return
    # Reapplying a theme should retain the selected wallpaper.
    if (ROOT / 'current.name').exists() and (ROOT / 'current.name').read_text().strip() == name:
        background = ROOT / 'current/background'
        if background.exists():
            target = stage / 'background'
            target.unlink(missing_ok=True)
            target.symlink_to(background.resolve())


def validate(stage):
    if (stage / 'starship.toml').exists():
        tomllib.loads((stage / 'starship.toml').read_text())
    for item in stage.iterdir():
        if item.suffix in ('.conf', '.lua', '.css', '.scss', '.toml', '.jsonc', '.ini', '.theme') and item.is_file():
            if TOKEN.search(item.read_text()):
                raise ValueError(f'Unresolved template placeholder in {item.name}')
    # Parse the full Hyprland configuration with only the theme include changed.
    config = Path.home() / '.config/hypr/hyprland.conf'
    if config.exists() and shutil.which('hyprland'):
        text = config.read_text()
        needle = '~/.config/themes/current/hyprland.conf'
        if needle not in text:
            raise ValueError('Cannot locate theme include for Hyprland validation')
        candidate = stage / '.validate-hyprland.conf'
        candidate.write_text(text.replace('~/.config/themes/current/', str(stage) + '/'))
        result = run(['hyprland', '--verify-config', '-c', candidate])
        candidate.unlink()
        if result.returncode or 'config ok' not in result.stdout + result.stderr:
            raise ValueError('Hyprland validation failed:\n' + result.stdout + result.stderr)
    # Same for the Lua entry point: point its theme directory at the stage and parse it.
    lua_config = Path.home() / '.config/hypr/hyprland.lua'
    if lua_config.exists() and shutil.which('hyprland'):
        text = lua_config.read_text()
        needle = 'local theme = home .. "/.config/themes/current"'
        if needle not in text:
            raise ValueError('Cannot locate theme directory in hyprland.lua for validation')
        candidate = stage / '.validate-hyprland.lua'
        candidate.write_text(text.replace(needle, 'local theme = ' + json.dumps(str(stage))))
        try:
            result = run(['hyprland', '--verify-config', '-c', candidate])
        finally:
            candidate.unlink()
        if result.returncode or 'config ok' not in result.stdout + result.stderr:
            raise ValueError('Hyprland (Lua) validation failed:\n' + result.stdout + result.stderr)
    scss = Path.home() / '.config/eww/eww.scss'
    if scss.exists() and shutil.which('sassc'):
        candidate = stage / '.validate-eww.scss'
        candidate.write_text(scss.read_text().replace('@import "theme";', (stage / 'eww-colors.scss').read_text()))
        result = run(['sassc', candidate])
        candidate.unlink()
        if result.returncode:
            raise ValueError('Dashboard SCSS validation failed: ' + result.stderr)
    if shutil.which('fastfetch'):
        result = run(['fastfetch', '--config', stage / 'fastfetch.jsonc', '--format', 'json'])
        if result.returncode:
            raise ValueError('Fastfetch validation failed: ' + result.stderr)


def exchange(a, b):
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.renameat2(-100, os.fsencode(a), -100, os.fsencode(b), 2):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))


def write_name(name):
    temp = ROOT / '.current.name.tmp'
    temp.write_text(name + '\n')
    temp.replace(ROOT / 'current.name')


def reload_apps(name):
    warnings = []
    wallpaper = 'syna-theme-bg-restore' if (ROOT / 'current/background').exists() else 'syna-theme-bg-next'
    commands = [(wallpaper, None), ('syna-restart-waybar', 'waybar'),
                ('syna-restart-swayosd', 'swayosd-server'), ('syna-restart-terminal', None),
                ('syna-restart-btop', 'btop'), ('syna-restart-opencode', 'opencode'),
                ('syna-restart-mako', 'mako'), ('syna-theme-set-walker', None),
                ('syna-theme-set-gnome', None)]
    for cmd, process in commands:
        if process and run(['pgrep', '-x', process]).returncode:
            continue
        try:
            result = run([SCRIPTS / cmd])
            if result.returncode:
                warnings.append(cmd)
        except (OSError, subprocess.TimeoutExpired):
            warnings.append(cmd)
    try:
        if shutil.which('eww') and not run(['pgrep', '-x', 'eww']).returncode:
            if run(['eww', 'reload']).returncode:
                warnings.append('eww reload')
    except (OSError, subprocess.TimeoutExpired):
        warnings.append('eww reload')
    for cmd, needed in [('syna-theme-set-vscode', (ROOT / 'current/vscode.json').exists()),
                        ('syna-theme-set-obsidian', (Path.home() / '.config/obsidian/obsidian.json').exists()),
                        ('syna-theme-set-browser', bool(shutil.which('chromium') or shutil.which('brave')))]:
        if needed:
            try:
                if run([SCRIPTS / cmd]).returncode:
                    warnings.append(cmd)
            except (OSError, subprocess.TimeoutExpired):
                warnings.append(cmd)
    try:
        if run([SCRIPTS / 'syna-hook', 'theme-set', name]).returncode:
            warnings.append('theme-set hook')
    except (OSError, subprocess.TimeoutExpired):
        warnings.append('theme-set hook')
    return warnings


def apply(stage, previous=False):
    current = ROOT / 'current'
    old_name = (ROOT / 'current.name').read_text().strip()
    (current / '.theme-name').write_text(old_name + '\n')
    name = (stage / '.theme-name').read_text().strip()
    exchange(current, stage)
    try:
        write_name(name)
        if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
            result = run(['hyprctl', 'reload'])
            errors = run(['hyprctl', 'configerrors', '-j'])
            if result.returncode or errors.returncode or any(str(error).strip() for error in json.loads(errors.stdout)):
                raise ValueError('Hyprland rejected the theme: ' + errors.stdout)
    except Exception:
        exchange(current, stage)
        write_name(old_name)
        if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
            run(['hyprctl', 'reload'])
        raise
    if not previous:
        backup = ROOT / 'previous'
        if backup.is_symlink():
            backup.unlink()
        elif backup.exists():
            shutil.rmtree(backup)
        stage.rename(backup)
    warnings = reload_apps(name)
    label_file = ROOT / '.overrides' / (name + '.name')
    label = label_file.read_text().strip() if label_file.is_file() else name
    message = f'Applied {label}.'
    if warnings:
        message += ' Reload warnings: ' + ', '.join(warnings)
    print(message)
    if shutil.which('notify-send'):
        try:
            run(['notify-send', 'Theme applied with warnings' if warnings else 'Theme changed', message])
        except (OSError, subprocess.TimeoutExpired):
            print('Warning: desktop notification unavailable', file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('theme', nargs='?')
    parser.add_argument('--check', action='store_true', help='Validate without changing the desktop')
    parser.add_argument('--previous', action='store_true', help='Restore the previous prepared theme')
    args = parser.parse_args()
    with (ROOT / '.switch.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.previous:
            stage = ROOT / 'previous'
            validate(stage)
            if not args.check:
                apply(stage, previous=True)
            return
        if not args.theme:
            parser.error('provide a theme name or --previous')
        name = re.sub(r'<[^>]+>', '', args.theme).lower().replace(' ', '-')
        stage = Path(tempfile.mkdtemp(prefix='.syna-stage-', dir=ROOT))
        try:
            build(name, stage)
            validate(stage)
            if args.check:
                print(f'{name}: validation passed')
            else:
                apply(stage)
        finally:
            if stage.exists():
                shutil.rmtree(stage)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'Theme switch failed: {error}', file=sys.stderr)
        sys.exit(1)
