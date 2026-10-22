"""Persistent personal theme settings and reversible wallpaper management."""
from pathlib import Path
import json
import os
import re
import shutil
import uuid
import unicodedata
import fcntl
import hashlib
import tempfile

ROOT = Path.home() / '.config/themes'
EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.avif'}


def theme(name):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', name) or name in {'current', 'previous', 'templates', 'backgrounds', 'next-theme'}:
        raise ValueError('Invalid theme')
    p = ROOT / name
    if p.is_symlink() or not (p / 'colors.toml').is_file():
        raise ValueError('Theme palette missing')
    return p


def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name('.' + path.name + '.' + uuid.uuid4().hex)
    try:
        tmp.write_text(text)
        os.replace(tmp, path)
    finally:
        tmp.unlink(missing_ok=True)


def wallpapers(name):
    base = theme(name)
    result = []
    for folder in [base / 'backgrounds', ROOT / 'backgrounds' / name]:
        if folder.is_symlink():
            continue
        if folder.exists():
            result.extend(p for p in folder.iterdir() if p.is_file() and not p.is_symlink() and p.suffix.lower() in EXTENSIONS)
    return sorted(result)


def selected(name):
    p = ROOT / '.overrides' / (name + '.wallpaper')
    return Path(p.read_text().strip()) if p.is_file() else None


def select(name, path):
    if path not in wallpapers(name):
        raise ValueError('Wallpaper is not part of this theme')
    atomic(ROOT / '.overrides' / (name + '.wallpaper'), str(path) + '\n')


def import_wallpaper(name, source):
    theme(name)
    if not source.is_file() or source.suffix.lower() not in EXTENSIONS:
        raise ValueError('Choose a PNG, JPEG, WebP or AVIF image')
    target = ROOT / 'backgrounds' / name
    target.mkdir(parents=True, exist_ok=True)
    namepart = re.sub(r'[^a-zA-Z0-9._-]', '_', source.stem)[:80] or 'wallpaper'
    dest = target / (namepart + '-' + uuid.uuid4().hex[:8] + source.suffix.lower())
    shutil.copy2(source, dest)
    return dest


def remove(name, path):
    images = wallpapers(name)
    if path not in images:
        raise ValueError('Wallpaper is not part of this theme')
    archive = ROOT / '.removed-wallpapers' / uuid.uuid4().hex
    archive.mkdir(parents=True)
    shutil.move(path, archive / path.name)
    atomic(archive / 'restore.json', json.dumps({'theme': name, 'original': str(path), 'file': path.name}))
    remaining = [p for p in images if p != path]
    if selected(name) == path:
        if remaining:
            select(name, remaining[0])
        else:
            (ROOT / '.overrides' / (name + '.wallpaper')).unlink(missing_ok=True)
    # Repair the active link before the next application rebuilds its snapshot.
    link = ROOT / 'current/background'
    if link.is_symlink() and link.resolve() == path.resolve():
        link.unlink()
        if remaining:
            link.symlink_to(remaining[0])
    return archive


def removed_archives(name):
    theme(name)
    folder = ROOT / '.removed-wallpapers'
    entries = []
    if folder.exists():
        for archive in folder.iterdir():
            try:
                if not archive.is_symlink() and json.loads((archive / 'restore.json').read_text()).get('theme') == name:
                    entries.append(archive)
            except (OSError, ValueError):
                continue
    return sorted(entries, key=lambda p: p.stat().st_mtime)


def undo(archive):
    if archive.parent != ROOT / '.removed-wallpapers' or archive.is_symlink():
        raise ValueError('Invalid wallpaper archive')
    data = json.loads((archive / 'restore.json').read_text())
    destination = Path(data['original'])
    allowed = [theme(data['theme']) / 'backgrounds', ROOT / 'backgrounds' / data['theme']]
    if destination.parent not in allowed or destination.exists() or data['file'] != destination.name:
        raise ValueError('Cannot restore over an existing file or outside this theme')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(archive / data['file'], destination)
    (archive / 'restore.json').unlink()
    archive.rmdir()
    return destination


def display_name(name):
    path = ROOT / '.overrides' / (name + '.name')
    return path.read_text().strip() if path.is_file() else name.replace('-', ' ').title()


def rename(name, label):
    theme(name)
    label = label.strip()
    if not label or len(label) > 60 or any(unicodedata.category(c).startswith('C') for c in label):
        raise ValueError('Use 1–60 characters without control characters.')
    for directory in ROOT.iterdir():
        if directory.name == name or directory.name.startswith('.') or directory.name in {'current', 'previous', 'templates', 'backgrounds', 'next-theme'}:
            continue
        if directory.is_dir() and (directory / 'colors.toml').is_file() and display_name(directory.name).casefold() == label.casefold():
            raise ValueError('Another theme already uses that name.')
    atomic(ROOT / '.overrides' / (name + '.name'), label + '\n')
    return label


def duplicate(name, label):
    """Copy local palette/styles/images, preserving only previously trusted styles."""
    source = theme(name)
    label = label.strip()
    if not label or len(label) > 60 or any(unicodedata.category(c).startswith('C') for c in label):
        raise ValueError('Use 1–60 characters without control characters.')
    with (ROOT / '.switch.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        for p in ROOT.iterdir():
            if p.is_dir() and not p.name.startswith('.') and p.name not in {'current', 'previous', 'next-theme', 'templates', 'backgrounds'} and (p/'colors.toml').is_file():
                if display_name(p.name).casefold() == label.casefold():
                    raise ValueError('Another theme already uses that name.')
        slug = re.sub('[^a-z0-9]+', '-', unicodedata.normalize('NFKD', label).encode('ascii', 'ignore').decode().lower()).strip('-') or 'theme'
        if slug in {'current', 'previous', 'next-theme', 'templates', 'backgrounds'}:
            slug += '-copy'
        target = slug
        index = 2
        while (ROOT / target).exists() or any((ROOT/'.overrides'/(target+ext)).exists() for ext in ['.name', '.toml', '.prompt.toml', '.window.toml', '.nvim.toml', '.wallpaper']):
            target = slug + '-' + str(index); index += 1
        stage = Path(tempfile.mkdtemp(prefix='.duplicate-', dir=ROOT))
        destination = ROOT / target
        manifest_path = ROOT / '.trusted-styles.json'
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
        trusted = {}
        try:
            shutil.copy2(source/'colors.toml', stage/'colors.toml')
            for p in source.iterdir():
                if not p.is_file() or p.is_symlink() or p.name == 'colors.toml':
                    continue
                digest = hashlib.sha256(p.read_bytes()).hexdigest()
                if manifest.get(name, {}).get(p.name) == digest:
                    shutil.copy2(p, stage/p.name)
                    trusted[p.name] = digest
                elif p.name == 'light.mode':
                    (stage/p.name).touch()
            images = wallpapers(name)
            mapping = {}
            (stage/'backgrounds').mkdir()
            for index, image in enumerate(images):
                filename = image.name
                if (stage/'backgrounds'/filename).exists():
                    filename = str(index) + '-' + filename
                shutil.copy2(image, stage/'backgrounds'/filename)
                mapping[image.resolve()] = destination/'backgrounds'/filename
            chosen = selected(name)
            if (ROOT/'current.name').is_file() and (ROOT/'current.name').read_text().strip() == name:
                active = ROOT/'current/background'
                if active.is_file(): chosen = active.resolve()
            for ext in ['.toml', '.prompt.toml', '.window.toml', '.nvim.toml']:
                personal = ROOT/'.overrides'/(name+ext)
                if personal.is_file() and not personal.is_symlink():
                    atomic(ROOT/'.overrides'/(target+ext), personal.read_text())
            atomic(ROOT/'.overrides'/(target+'.name'), label+'\n')
            if chosen is not None and chosen.resolve() in mapping:
                atomic(ROOT/'.overrides'/(target+'.wallpaper'), str(mapping[chosen.resolve()])+'\n')
            manifest[target] = trusted
            atomic(manifest_path, json.dumps(manifest, indent=2)+'\n')
            stage.rename(destination)
            return target
        except Exception:
            for ext in ['.name', '.toml', '.prompt.toml', '.window.toml', '.nvim.toml', '.wallpaper']:
                (ROOT/'.overrides'/(target+ext)).unlink(missing_ok=True)
            if target in manifest:
                del manifest[target]
                atomic(manifest_path, json.dumps(manifest, indent=2)+'\n')
            raise
        finally:
            if stage.exists(): shutil.rmtree(stage)


def remove_theme(name):
    """Archive a non-active theme and its personal settings under the switch lock."""
    source = theme(name)
    with (ROOT / '.switch.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if (ROOT / 'current.name').read_text().strip() == name:
            raise ValueError('Switch to another theme before removing this one.')
        archive = ROOT / '.removed-themes' / (name + '-' + uuid.uuid4().hex)
        archive.mkdir(parents=True)
        paths = [(source, 'theme')]
        personal_images = ROOT / 'backgrounds' / name
        if personal_images.exists(): paths.append((personal_images, 'personal-wallpapers'))
        for ext in ['.name', '.toml', '.prompt.toml', '.window.toml', '.nvim.toml', '.wallpaper']:
            p = ROOT / '.overrides' / (name + ext)
            if p.exists(): paths.append((p, 'override' + ext))
        previous = ROOT / 'previous'
        metadata = previous / '.theme-name'
        if metadata.is_file() and metadata.read_text().strip() == name:
            paths.append((previous, 'previous'))
        manifest_path = ROOT / '.trusted-styles.json'
        original_manifest = manifest_path.read_text() if manifest_path.exists() else None
        manifest = json.loads(original_manifest) if original_manifest is not None else {}
        moved = []
        try:
            atomic(archive / 'restore.json', json.dumps({
                'id': name, 'name': display_name(name),
                'paths': [{'original': str(p), 'archived': target} for p, target in paths],
                'trusted_styles': manifest.get(name, {})}, indent=2))
            for p, target in paths:
                destination = archive / target
                p.rename(destination)
                moved.append((p, destination))
            manifest.pop(name, None)
            if original_manifest is not None:
                atomic(manifest_path, json.dumps(manifest, indent=2) + '\n')
            return archive
        except Exception:
            for original, archived in reversed(moved):
                archived.rename(original)
            if original_manifest is not None:
                atomic(manifest_path, original_manifest)
            shutil.rmtree(archive)
            raise


def removed_themes():
    folder = ROOT / '.removed-themes'
    entries = []
    if folder.exists():
        for archive in folder.iterdir():
            try:
                if archive.is_symlink(): continue
                data = json.loads((archive / 'restore.json').read_text())
                if not data.get('restored'):
                    entries.append((archive, data))
            except (OSError, ValueError):
                continue
    return sorted(entries, key=lambda item: item[0].stat().st_mtime, reverse=True)


def restore_theme(archive):
    if archive.parent != ROOT / '.removed-themes' or archive.is_symlink():
        raise ValueError('Invalid theme archive')
    with (ROOT / '.switch.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        data = json.loads((archive / 'restore.json').read_text())
        name = data['id']
        if data.get('restored') or not re.fullmatch(r'[a-z0-9][a-z0-9-]*', name) or name in {'current','previous','templates','backgrounds','next-theme'}:
            raise ValueError('Invalid or already restored theme')
        allowed = {'theme': ROOT / name, 'personal-wallpapers': ROOT / 'backgrounds' / name}
        for ext in ['.name', '.toml', '.prompt.toml', '.window.toml', '.nvim.toml', '.wallpaper']:
            allowed['override'+ext] = ROOT / '.overrides' / (name+ext)
        paths = []
        for item in data['paths']:
            if item['archived'] == 'previous':
                continue  # Recovery must not replace today's previous-theme snapshot.
            dest = allowed.get(item['archived'])
            if dest is None or str(dest) != item['original']:
                raise ValueError('Invalid archive destination')
            source = archive / item['archived']
            if not source.exists() or source.is_symlink():
                raise ValueError('Archive is incomplete')
            if dest.exists() or dest.is_symlink():
                raise ValueError('A theme or settings with this ID already exist. Rename/remove the conflicting copy first.')
            paths.append((source, dest))
        if not any(p == ROOT / name for _, p in paths):
            raise ValueError('Theme files missing from archive')
        for p in ROOT.iterdir():
            if p.is_dir() and not p.name.startswith('.') and p.name not in {'current','previous','templates','backgrounds','next-theme'} and (p/'colors.toml').is_file():
                if display_name(p.name).casefold() == data['name'].casefold():
                    raise ValueError('An installed theme already uses this display name.')
        # Restore only trust hashes whose archived bytes still match.
        trusted = {}
        for filename, digest in data.get('trusted_styles', {}).items():
            if Path(filename).name != filename: continue
            file = archive / 'theme' / filename
            if file.is_file() and not file.is_symlink() and hashlib.sha256(file.read_bytes()).hexdigest() == digest:
                trusted[filename] = digest
        manifest_path = ROOT / '.trusted-styles.json'
        old = manifest_path.read_text() if manifest_path.exists() else None
        manifest = json.loads(old) if old else {}
        moved = []
        try:
            for source, dest in paths:
                dest.parent.mkdir(parents=True, exist_ok=True)
                source.rename(dest); moved.append((source, dest))
            manifest[name] = trusted
            atomic(manifest_path, json.dumps(manifest, indent=2)+'\n')
            data['restored'] = True
            atomic(archive / 'restore.json', json.dumps(data, indent=2)+'\n')
        except Exception:
            for source, dest in reversed(moved): dest.rename(source)
            if old is None: manifest_path.unlink(missing_ok=True)
            else: atomic(manifest_path, old)
            raise
        return name


def delete_permanently(archive, confirmation):
    """Delete only a removed-theme archive, after an exact-name confirmation."""
    folder = ROOT / '.removed-themes'
    if folder.is_symlink() or archive.parent != folder or archive.is_symlink() or not archive.is_dir():
        raise ValueError('Invalid theme archive')
    with (ROOT / '.switch.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        data = json.loads((archive / 'restore.json').read_text())
        if data.get('restored'):
            raise ValueError('This theme has already been restored.')
        if not data.get('name') or confirmation != data['name']:
            raise ValueError('Type the theme name exactly to confirm permanent deletion.')
        # Never follow restore metadata paths or links into installed themes.
        shutil.rmtree(archive)
