#!/usr/bin/env python3
"""Validate theme paths and generate configs from palette data, never theme code."""
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import tomllib

RESERVED = {'current', 'previous', 'next-theme', 'templates', 'backgrounds'}
ROOT = Path.home() / '.config/themes'

def theme_path(name):
    if not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}', name) or name in RESERVED:
        raise ValueError('Invalid or reserved theme name')
    path = ROOT / name
    if path.is_symlink():
        raise ValueError('Theme directories must not be symlinks')
    return path

def palette(source):
    file = source / 'colors.toml'
    if file.is_symlink():
        raise ValueError('Palette must not be a symlink')
    if file.is_file():
        colors = tomllib.loads(file.read_text())
    else:
        file = source / 'alacritty.toml'
        if file.is_symlink():
            raise ValueError('Legacy palette must not be a symlink')
        old = tomllib.loads(file.read_text())['colors']
        colors = dict(old['primary'])
        for prefix, base in [('normal', 0), ('bright', 8)]:
            for i, key in enumerate(['black','red','green','yellow','blue','magenta','cyan','white']):
                colors[f'color{base+i}'] = old[prefix][key]
        colors['accent'] = colors['color4']
        colors['cursor'] = old.get('cursor', {}).get('cursor', colors['foreground'])
    for key, value in colors.items():
        if not re.fullmatch(r'[a-zA-Z][a-zA-Z0-9_]*', key) or not isinstance(value,str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
            raise ValueError(f'Palette entry {key!r} must be a six-digit hex color')
    colors.setdefault('accent', colors['color4'])
    colors.setdefault('cursor', colors['foreground'])
    colors.setdefault('selection_foreground', colors['background'])
    colors.setdefault('selection_background', colors['accent'])
    colors.setdefault('border_top', colors['accent'])
    colors.setdefault('border_bottom', colors['foreground'])
    return colors

def render(colors, target):
    replacements = dict(colors)
    for key, value in colors.items():
        replacements[key+'_strip'] = value[1:]
        replacements[key+'_rgb'] = ','.join(str(int(value[i:i+2],16)) for i in (1,3,5))
    outputs = {}
    for tpl in (ROOT / 'templates').glob('*.tpl'):
        def substitute(match):
            key = match[1].strip()
            if key not in replacements:
                raise ValueError(f'Missing template color {key}')
            return replacements[key]
        outputs[tpl.name[:-4]] = re.sub(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}', substitute, tpl.read_text())
    for name, text in outputs.items():
        dest=target/name
        if dest.is_symlink(): dest.unlink()
        dest.write_text(text)

def stage(name):
    source = theme_path(name)
    colors = palette(source)
    with tempfile.TemporaryDirectory(prefix='.stage-',dir=ROOT) as tmp:
        target=Path(tmp)
        render(colors,target)
        (target/'colors.toml').write_text(''.join(f'{k} = "{v}"\n' for k,v in colors.items()))
        backgrounds=source/'backgrounds'
        if backgrounds.is_dir() and not backgrounds.is_symlink():
            for base, dirs, files in os.walk(backgrounds, followlinks=False):
                dirs[:] = [d for d in dirs if not (Path(base)/d).is_symlink()]
                for name in files:
                    src=Path(base)/name
                    if src.is_symlink() or src.suffix.lower() not in {'.png','.jpg','.jpeg','.webp','.avif'}: continue
                    dest=target/'backgrounds'/src.relative_to(backgrounds)
                    dest.parent.mkdir(parents=True,exist_ok=True)
                    shutil.copyfile(src,dest)
        for flag in ('light.mode',):
            if (source/flag).is_file() and not (source/flag).is_symlink(): (target/flag).touch()
        dest=ROOT/'next-theme'
        if dest.is_symlink(): dest.unlink()
        elif dest.exists(): shutil.rmtree(dest)
        os.replace(target,dest)

if __name__=='__main__':
    try:
        action=sys.argv[1]
        if action=='validate': print(theme_path(sys.argv[2]))
        elif action=='stage': stage(sys.argv[2])
        elif action=='render': render(palette(ROOT/'next-theme'),ROOT/'next-theme')
        elif action=='check': palette(Path(sys.argv[2]))
        else: raise ValueError('Unknown operation')
    except (ValueError, OSError, KeyError, IndexError) as error:
        sys.exit(f'Theme rejected: {error}')
