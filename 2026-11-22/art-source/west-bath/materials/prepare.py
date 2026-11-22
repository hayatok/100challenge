"""Make edge-matched colour maps while retaining the unmodified MOSS originals."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT.parents[2] / "Game/Assets/Resources/KinseiWestBath"


def join_edges(image, axis):
    lines = np.swapaxes(image, 0, axis)
    width = min(40, len(lines) // 8)
    low = lines[:width].copy()
    high = lines[-width:][::-1].copy()
    weight = np.linspace(1.0, 0.0, width)[:, None, None]
    weight = weight * weight * (3 - 2 * weight)
    adjustment = (high - low) * .5 * weight
    lines[:width] = low + adjustment
    lines[-width:] = (high - adjustment)[::-1]


OUTPUT.mkdir(parents=True, exist_ok=True)
for name in ("Tile", "Terrazzo", "Noren", "Mat", "Glass"):
    path = ROOT / (name + ".png")
    record = json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record["sha256"]
    with Image.open(path) as source:
        pixels = np.array(source.convert("RGB"), dtype=np.float32)
    join_edges(pixels, 0)
    join_edges(pixels, 1)
    colour = Image.fromarray(np.rint(pixels).clip(0, 255).astype("uint8"))
    colour.save(OUTPUT / (name + ".jpg"), quality=94, subsampling=0, optimize=True)
