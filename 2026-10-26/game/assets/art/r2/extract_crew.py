"""Extract existing isolated alpha components; never paint or recolor source pixels."""
from pathlib import Path
from collections import deque
import json
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).parent
source = Image.open(ROOT / 'crew-field.png').convert('RGBA')
rgba = np.array(source)
mask = rgba[:, :, 3] > 8
height, width = mask.shape
components = []
for y, x in zip(*np.where(mask)):
    if not mask[y, x]:
        continue
    pending = deque([(int(x), int(y))])
    mask[y, x] = False
    pixels = []
    while pending:
        cx, cy = pending.popleft()
        pixels.append((cx, cy))
        for nx, ny in [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)]:
            if 0 <= nx < width and 0 <= ny < height and mask[ny, nx]:
                mask[ny, nx] = False
                pending.append((nx, ny))
    if len(pixels) > 1000:
        components.append(pixels)

assert len(components) == 4, 'Expected exactly four principal silhouettes'
components.sort(key=lambda points: (min(y for _, y in points) // 600, min(x for x, _ in points)))
results = []
for name, pixels in zip(['isana', 'ritsu', 'kohaku', 'sui'], components):
    xs, ys = zip(*pixels)
    bounds = (max(0, min(xs) - 4), max(0, min(ys) - 4), min(width, max(xs) + 5), min(height, max(ys) + 5))
    selection = np.zeros((height, width), dtype=np.uint8)
    for x, y in pixels:
        selection[y, x] = 255
    # A two-pixel outward selection retains original low-alpha edge antialiasing.
    expanded = np.array(Image.fromarray(selection).filter(ImageFilter.MaxFilter(5))) > 0
    isolated = rgba.copy()
    isolated[~expanded, 3] = 0
    output = Image.fromarray(isolated).crop(bounds)
    output.save(ROOT / f'crew-{name}.png')
    alpha = np.array(output.getchannel('A'))
    results.append({'character': name, 'file': f'crew-{name}.png', 'sourceRect': [bounds[0], bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1]], 'dimensions': list(output.size), 'alphaMin': int(alpha.min()), 'alphaMax': int(alpha.max()), 'fullyTransparentPixels': int((alpha == 0).sum()), 'cornerAlpha': [int(alpha[y, x]) for x, y in [(0, 0), (output.width-1, 0), (0, output.height-1), (output.width-1, output.height-1)]]})
print(json.dumps(results, indent=2))
