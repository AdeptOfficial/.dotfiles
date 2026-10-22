"""Offline wallpaper palette provider; produces the same data contract as future AI providers."""
import colorsys
import fcntl
import re
import shutil
import tempfile
import unicodedata
import warnings
from pathlib import Path
from PIL import Image, ImageOps


def rgb(value):
    return tuple(int(value[i:i+2],16)/255 for i in (1,3,5))


def hexcolor(c):
    return '#%02x%02x%02x' % tuple(round(max(0,min(1,v))*255) for v in c)


def contrast(a,b):
    def luminance(value):
        c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb(value)]
        return sum(x*y for x,y in zip(c,(.2126,.7152,.0722)))
    x,y=sorted((luminance(a),luminance(b)))
    return (y+.05)/(x+.05)


def readable(color,background,minimum=4.5):
    # Raise lightness while preserving hue/saturation instead of mixing in white.
    h,l,s=colorsys.rgb_to_hls(*rgb(color))
    for step in range(101):
        value=hexcolor(colorsys.hls_to_rgb(h,l+(1-l)*step/100,s))
        if contrast(value,background)>=minimum:return value
    return '#ffffff'


def sample_colors(path):
    with warnings.catch_warnings():
        warnings.simplefilter('error',Image.DecompressionBombWarning)
        with Image.open(path) as image:
            image=ImageOps.exif_transpose(image)
            image.thumbnail((256,256))
            rgba=image.convert('RGBA')
            solid=Image.new('RGBA',rgba.size,'#10131a');solid.alpha_composite(rgba)
            reduced=solid.convert('RGB').quantize(colors=48)
            table=reduced.getpalette()
            counted=sorted(reduced.getcolors(),reverse=True)
            return [(count,tuple(table[index*3+i]/255 for i in range(3))) for count,index in counted]


def accent_choices(path):
    samples=sample_colors(path)
    total=sum(n for n,_ in samples)
    def score(item):
        n,c=item;h,s,v=colorsys.rgb_to_hsv(*c)
        return s*s*v*(n/total)**.2
    ranked=sorted(samples,key=score,reverse=True)
    choices=[]
    for _,color in ranked:
        h,s,v=colorsys.rgb_to_hsv(*color)
        if choices and any(min(abs(h-colorsys.rgb_to_hsv(*rgb(old))[0]),1-abs(h-colorsys.rgb_to_hsv(*rgb(old))[0]))<.08 for old in choices):
            continue
        choices.append(hexcolor(color))
        if len(choices)==6:break
    return choices


def extract(path):
    samples=[c for _,c in sample_colors(path)]
    dominant=samples[0]
    h,l,s=colorsys.rgb_to_hls(*dominant)
    background=hexcolor(colorsys.hls_to_rgb(h,.07,min(s,.35)))
    accent=readable(accent_choices(path)[0],background)
    foreground=readable(hexcolor(colorsys.hls_to_rgb(h,.90,min(s,.15))),background,7)
    colors={'background':background,'foreground':foreground,'accent':accent,'cursor':foreground,
            'selection_background':accent,'selection_foreground':background,'border_top':accent,'border_bottom':foreground}
    colors['color0']=hexcolor(colorsys.hls_to_rgb(h,.14,min(s,.3)))
    colors['color8']=readable(hexcolor(colorsys.hls_to_rgb(h,.42,min(s,.2))),background,3)
    for index,target in enumerate([0,120/360,55/360,225/360,290/360,180/360],1):
        def distance(c):
            hue,_,sat=colorsys.rgb_to_hls(*c)
            return min(abs(hue-target),1-abs(hue-target)) if sat>.15 else 2
        nearest=min(samples,key=distance)
        base=readable(hexcolor(nearest),background)
        colors['color'+str(index)]=base
        hue,lightness,sat=colorsys.rgb_to_hls(*rgb(base))
        colors['color'+str(index+8)]=readable(hexcolor(colorsys.hls_to_rgb(hue,min(.9,lightness+.10),sat)),background)
    colors['color7']=foreground;colors['color15']='#f5f7fa'
    return colors


def validate_colors(colors):
    required={'background','foreground','accent','cursor','selection_background','selection_foreground','border_top','border_bottom'}|{'color'+str(i) for i in range(16)}
    if set(colors)!=required or any(not re.fullmatch('#[0-9a-fA-F]{6}',str(v)) for v in colors.values()):
        raise ValueError('Invalid palette data')
    if contrast(colors['foreground'],colors['background'])<4.5:
        raise ValueError('Text needs more contrast against the background (minimum 4.5:1).')
    if contrast(colors['accent'],colors['background'])<3:
        raise ValueError('Accent needs more contrast against the background (minimum 3:1).')
    if contrast(colors['selection_foreground'],colors['selection_background'])<4.5:
        raise ValueError('Selected text needs more contrast (minimum 4.5:1).')


def create(label, image_path, colors, custom, engine):
    """Publish validated palette + sanitized image only; never activate the desktop."""
    validate_colors(colors)
    label=label.strip()
    if not label or len(label)>60 or any(unicodedata.category(c).startswith('C') for c in label):
        raise ValueError('Use a name of 1–60 characters without control characters.')
    root=custom.ROOT
    with (root/'.switch.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        for p in root.iterdir():
            if p.is_dir() and not p.name.startswith('.') and p.name not in {'current','previous','templates','backgrounds','next-theme'} and (p/'colors.toml').exists() and custom.display_name(p.name).casefold()==label.casefold():
                raise ValueError('Another theme already uses this name.')
        slug=re.sub('[^a-z0-9]+','-',unicodedata.normalize('NFKD',label).encode('ascii','ignore').decode().lower()).strip('-') or 'theme'
        if slug in {'current','previous','templates','backgrounds','next-theme'}:slug+='-theme'
        name=slug;index=2
        while (root/name).exists() or any((root/'.overrides'/(name+e)).exists() for e in ['.name','.toml','.wallpaper']):
            name=slug+'-'+str(index);index+=1
        stage=Path(tempfile.mkdtemp(prefix='.create-',dir=root))
        try:
            (stage/'colors.toml').write_text(''.join(f'{k} = "{v}"\n' for k,v in colors.items()))
            (stage/'backgrounds').mkdir()
            with warnings.catch_warnings():
                warnings.simplefilter('error',Image.DecompressionBombWarning)
                with Image.open(image_path) as image:
                    ImageOps.exif_transpose(image).convert('RGB').save(stage/'backgrounds/wallpaper.png')
            # Use the normal parser/preflight without installing or executing image-provided config.
            with tempfile.TemporaryDirectory(prefix='.create-check-',dir=root) as tmp:
                check=Path(tmp)
                palette=engine.palette(stage/'colors.toml')
                for template in (root/'templates').glob('*.tpl'):
                    (check/template.name.removesuffix('.tpl')).write_text(engine.render(template.read_text(),palette))
                engine.validate(check)
            custom.atomic(root/'.overrides'/(name+'.name'),label+'\n')
            custom.atomic(root/'.overrides'/(name+'.wallpaper'),str(root/name/'backgrounds/wallpaper.png')+'\n')
            stage.rename(root/name)
            return name
        except Exception:
            for ext in ['.name','.wallpaper']:(root/'.overrides'/(name+ext)).unlink(missing_ok=True)
            raise
        finally:
            if stage.exists():shutil.rmtree(stage)


def save_existing(name, colors, custom, engine):
    """Save palette overrides; validate inactive themes, apply only the active one."""
    validate_colors(colors)
    custom.theme(name)
    path=custom.ROOT/'.overrides'/(name+'.toml')
    old=path.read_text() if path.exists() else None
    custom.atomic(path,''.join(f'{k} = "{v}"\n' for k,v in colors.items()))
    try:
        active=(custom.ROOT/'current.name').read_text().strip()==name
        args=[engine.SCRIPTS/'syna-theme-set']
        if not active:args.append('--check')
        result=engine.run(args+[name])
        if result.returncode:
            raise ValueError(result.stderr.strip() or result.stdout.strip() or 'Theme validation failed')
    except Exception:
        if old is None:path.unlink(missing_ok=True)
        else:custom.atomic(path,old)
        raise
    return name
