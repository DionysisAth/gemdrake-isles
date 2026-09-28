"""Builds every launcher icon from tool/icon/icon.svg.

  python3 tool/icon/make_icons.py
"""
import json, pathlib, subprocess, sys, tempfile
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).parent
RES = ROOT / 'android/app/src/main/res'
IOS = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'

def render(mode, out):
    subprocess.run([sys.executable, str(HERE / 'render.py'), str(out), mode], check=True)
    return Image.open(out).convert('RGBA')

with tempfile.TemporaryDirectory() as t:
    t = pathlib.Path(t)
    full = render('full', t / 'full.png')
    fg = render('fg', t / 'fg.png')
    bg = render('bg', t / 'bg.png')

full.convert('RGB').save(HERE / 'icon-1024.png')

# Android: legacy square icons + adaptive layers (108dp canvas).
dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for name, k in dens.items():
    d = RES / f'mipmap-{name}'
    d.mkdir(exist_ok=True)
    full.resize((round(48 * k),) * 2, Image.LANCZOS).save(d / 'ic_launcher.png')
    full.resize((round(48 * k),) * 2, Image.LANCZOS).save(d / 'ic_launcher_round.png')
    s = round(108 * k)
    fg.resize((s, s), Image.LANCZOS).save(d / 'ic_launcher_foreground.png')
    bg.resize((s, s), Image.LANCZOS).convert('RGB').save(d / 'ic_launcher_background.png')
any_dir = RES / 'mipmap-anydpi-v26'
any_dir.mkdir(exist_ok=True)
xml = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'''
(any_dir / 'ic_launcher.xml').write_text(xml)
(any_dir / 'ic_launcher_round.xml').write_text(xml)

# iOS: every size listed in Contents.json (no transparency allowed).
contents = json.loads((IOS / 'Contents.json').read_text())
for img in contents['images']:
    size = float(img['size'].split('x')[0])
    scale = int(img['scale'][0])
    px = round(size * scale)
    full.resize((px, px), Image.LANCZOS).convert('RGB').save(IOS / img['filename'])
print('icons written')
