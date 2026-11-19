"""Print the command book's four top-down plans from the actual Blender street meshes."""
from pathlib import Path
import struct

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "Game/Assets/Resources"
WIDTH, HEIGHT = 384, 640
X_RANGE, Z_RANGE = 43.0, 93.0


def plot_meshes(index):
    parcels = []
    names = [f"district{index}", f"landmark{index}", f"approach{index}North", f"approach{index}South"]
    for name in names:
        raw = (ROOT / "World" / (name + ".bytes")).read_bytes()
        count, = struct.unpack_from("<I", raw)
        stride = (len(raw) - 4) // count
        vertices = np.ndarray((count, 3), "<f4", raw, 4, (stride, 4)).reshape(-1, 3, 3)
        mean = vertices.mean(axis=1)
        upward = np.ndarray((count,), "i1", raw, 17, (stride,)).reshape(-1, 3).mean(axis=1)
        for triangle, center in zip(vertices[upward > 45], mean[upward > 45]):
            x, y, z = center
            if abs(x) > X_RANGE + 6 or abs(z) > Z_RANGE + 6 or y < -.1:
                continue
            rgb = (52, 67, 65) if y < .19 else (69, 82, 76) if y < .55 else (86, 97, 87) if y < 2.1 else (96, 105, 94)
            parcels.append((y, [(int((p[0]+X_RANGE)*WIDTH/(2*X_RANGE)), int((Z_RANGE-p[2])*HEIGHT/(2*Z_RANGE))) for p in triangle], rgb))
    sheet = Image.new("RGB", (WIDTH, HEIGHT), (31, 45, 43))
    ink = ImageDraw.Draw(sheet)
    for _, points, color in sorted(parcels, key=lambda part:part[0]):
        ink.polygon(points, fill=color)
    # Survey grid remains visible over building masses without introducing fake roads.
    grid = Image.new("RGBA", sheet.size)
    pen = ImageDraw.Draw(grid)
    for z in range(-80, 81, 20):
        y = int((Z_RANGE-z)*HEIGHT/(2*Z_RANGE))
        pen.line((0,y,WIDTH,y),fill=(197,207,183,55),width=1)
    for x in range(-40,41,20):
        u = int((x+X_RANGE)*WIDTH/(2*X_RANGE))
        pen.line((u,0,u,HEIGHT),fill=(197,207,183,36),width=1)
    return Image.alpha_composite(sheet.convert("RGBA"),grid).convert("RGB")


if __name__ == "__main__":
    atlas = Image.new("RGB",(WIDTH*4,HEIGHT))
    for region in range(4):
        atlas.paste(plot_meshes(region),(region*WIDTH,0))
    atlas.save(ROOT/"UI/OperationMaps.png",optimize=True)
