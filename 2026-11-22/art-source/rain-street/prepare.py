"""Bake height, pooling coverage and water slope maps for the rain shader."""
import hashlib
import json
import uuid
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent
RES = ROOT.parents[1] / 'Game/Assets/Resources'
OUT = RES / 'KinseiRainStreet'
OUT.mkdir(exist_ok=True)


def height(name):
    path = ROOT / (name + '.png')
    source = json.loads(path.with_suffix('.json').read_text(encoding='utf-8'))
    if hashlib.sha256(path.read_bytes()).hexdigest() != source['sha256']:
        raise ValueError('Changed source: ' + name)
    with Image.open(path) as image:
        channel = image.convert('L')
        if name == 'Basin':
            channel = channel.filter(ImageFilter.GaussianBlur(4))
        value = np.asarray(channel, dtype='float32').copy()
    # Meet the opposite edge over 20 texels while keeping the interior photograph intact.
    for axis in (0, 1):
        grid = np.swapaxes(value, 0, axis)
        low, high = grid[:20].copy(), grid[-20:][::-1].copy()
        mix = (.5 * np.linspace(1, 0, 20)[:, None]) * (high - low)
        grid[:20], grid[-20:] = low + mix, (high - mix)[::-1]
    return value


def normalized(values, percentiles):
    low, high = np.percentile(values, percentiles)
    return np.clip((values - low) / max(high - low, 1), 0, 1)


def meta(path, example, linear=True):
    if path.exists():
        return
    content = example.read_text(encoding='utf-8').splitlines()
    guid = uuid.uuid5(uuid.NAMESPACE_URL, 'kinsei/rain/v16/' + path.name).hex
    content = ['guid: ' + guid if line.startswith('guid: ') else line.rstrip() for line in content]
    if linear:
        content = ['    sRGBTexture: 0' if 'sRGBTexture:' in line else line for line in content]
    path.write_text('\n'.join(content) + '\n', encoding='utf-8')


meta(OUT.with_suffix('.meta'), RES / 'KinseiWestBath.meta')
for label in ('Asphalt', 'Basin', 'Ripple'):
    value = height(label)
    if label == 'Asphalt':
        surface = normalized(value, (2, 98))
    elif label == 'Basin':
        # Smooth dark hollows are water, the pale islands in the scan are drying aggregate.
        surface = 1 - normalized(value, (22, 76))
    else:
        dx = (np.roll(value, -1, axis=1) - np.roll(value, 1, axis=1)) * .5
        dy = (np.roll(value, -1, axis=0) - np.roll(value, 1, axis=0)) * .5
        slope = max(np.percentile(np.hypot(dx, dy), 98), 1)
        surface = np.stack((.5 + .48 * dx/slope, .5 - .48 * dy/slope, np.ones_like(value)), axis=2)
    image = Image.fromarray(np.rint(np.clip(surface, 0, 1) * 255).astype('uint8'))
    game_texture = OUT / (label + '.jpg')
    image.convert('RGB').save(game_texture, quality=94, subsampling=0)
    meta(game_texture.with_suffix('.jpg.meta'), RES / 'KinseiWestBath/Tile.jpg.meta')

for label in ('Enamel','Grille'):
    source=ROOT / (label + '.png')
    expected=json.loads(source.with_suffix('.json').read_text(encoding='utf-8'))['sha256']
    if hashlib.sha256(source.read_bytes()).hexdigest()!=expected:
        raise ValueError('Changed source: ' + label)
    dest=OUT / (label + '.jpg')
    with Image.open(source) as photo:
        photo.convert('RGB').save(dest,quality=94,subsampling=0)
    meta(dest.with_suffix('.jpg.meta'),RES / 'KinseiWestBath/Tile.jpg.meta',linear=False)


# RG8 in Unity's bottom-up texel order. Both the fragment shader and shoe contacts
# bilinearly sample these two linear height fields at their original world scales.
coverage_channels = []
for label in ('Asphalt', 'Basin'):
    with Image.open(OUT / (label + '.jpg')) as source:
        resized = source.getchannel('R').resize((256, 256), Image.Resampling.BOX)
        coverage_channels.append(np.asarray(resized)[::-1])
coverage_file = OUT / 'Coverage.bytes'
coverage_file.write_bytes(np.stack(coverage_channels, axis=-1).tobytes())
meta(coverage_file.with_suffix('.bytes.meta'), RES / 'KinseiWestCast/SeoCut.bytes.meta', linear=False)
