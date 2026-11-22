"""Prepare repeatable material maps and Unity import settings for the cabaret entrance."""
import hashlib
import json
import uuid
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parent
RESOURCES = ROOT.parents[1] / 'Game/Assets/Resources'
TARGET = RESOURCES / 'KinseiFrontage'


def repeatable_photo(name):
    path = ROOT / (name + '.png')
    record = json.loads(path.with_suffix('.json').read_text(encoding='utf-8'))
    if hashlib.sha256(path.read_bytes()).hexdigest() != record['sha256']:
        raise ValueError(f'Unexpected source for {name}')
    with Image.open(path) as original:
        rgb = np.array(original.convert('RGB'), dtype=np.float32)
    # Match opposite edges over the final centimetre of the swatch.
    blend = np.linspace(.5, 0, 16, dtype=np.float32)[:, None, None]
    for dimension in (0, 1):
        rows = rgb.swapaxes(0, dimension)
        first, last = rows[:16].copy(), rows[-16:][::-1].copy()
        delta = (last - first) * blend
        rows[:16] = first + delta
        rows[-16:] = (last - delta)[::-1]
    return Image.fromarray(np.rint(rgb).astype(np.uint8))


def write_meta(asset, template):
    meta = asset.with_suffix(asset.suffix + '.meta')
    if meta.exists():
        return
    guid = uuid.uuid5(uuid.NAMESPACE_URL, 'kinsei/frontage/v17/' + asset.name).hex
    lines = ['guid: ' + guid if line.startswith('guid: ') else line.rstrip()
             for line in template.read_text(encoding='utf-8').rstrip().splitlines()]
    meta.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def stone_normal(photo):
    # Approximate only the relief of grain edges. The colour of a polished
    # dark aggregate does not make it a deep hole in the slab.
    mono = photo.convert('L')
    field = np.asarray(mono, dtype=np.float32) - np.asarray(mono.filter(ImageFilter.GaussianBlur(1.6)), dtype=np.float32)
    relief_metres = np.clip(field / 55, -1, 1) * .00016
    metres_per_pixel = .64 / photo.width
    dx = (np.roll(relief_metres, -1, axis=1) - np.roll(relief_metres, 1, axis=1)) / (2 * metres_per_pixel)
    dy = (np.roll(relief_metres, -1, axis=0) - np.roll(relief_metres, 1, axis=0)) / (2 * metres_per_pixel)
    normals = np.stack((-dx, dy, np.ones_like(dx)), axis=2)
    normals /= np.linalg.norm(normals, axis=2, keepdims=True)
    return Image.fromarray(np.rint((.5 + normals * .5) * 255).astype(np.uint8))


if __name__ == '__main__':
    TARGET.mkdir(exist_ok=True)
    write_meta(TARGET, RESOURCES / 'KinseiWestBath.meta')
    for name in ('Stone', 'Skirting', 'Brass'):
        photo = repeatable_photo(name)
        asset = TARGET / (name + '.jpg')
        photo.save(asset, quality=95, subsampling=0)
        write_meta(asset, RESOURCES / 'KinseiRainStreet/Enamel.jpg.meta')
        if name == 'Stone':
            normal = TARGET / 'StoneNormal.png'
            stone_normal(photo).save(normal)
            write_meta(normal, RESOURCES / 'KinseiMakabe/MakabeWoolNormal.png.meta')
