"""Finish the four pane scans and the two azimuths of the sky surround."""

import argparse
import hashlib
import json
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from render import HERE, SPECS


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("work", type=Path)
    args = parser.parse_args()
    project = HERE.parents[1]
    resources = project / "Resources/KinseiNightscape"
    if (project / "Game/Assets/Resources").exists():
        resources = project / "Game/Assets/Resources/KinseiNightscape"
    resources.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGB", (1536, 1536))
    caption = [
        "台所の琥珀",
        "机の青緑",
        "楽屋のカーテン",
        "鉢植えの葉",
        "高架側の湿った空",
        "金星側の雲底",
    ]
    gallery = Image.new("RGB", (1240, 752), "#211e21")
    draw = ImageDraw.Draw(gallery)
    fonts = Path(os.environ["WINDIR"]) / "Fonts"
    draw.text(
        (22, 10),
        "宵待町　窓の奥と宵の空",
        font=ImageFont.truetype(str(fonts / "yumin.ttf"), 38),
        fill="#e8d5b5",
    )
    face = ImageFont.truetype(str(fonts / "meiryo.ttc"), 19)
    source = {}
    for i, (name, _, _, _) in enumerate(SPECS):
        with Image.open(args.work / (name + ".png")) as img:
            source[name] = img.convert("RGB")
        img = source[name]
        thumb = img.copy()
        thumb.thumbnail((384, 275), Image.Resampling.LANCZOS)
        x = 22 + (i % 3) * 405
        y = 76 + (i // 3) * 325
        gallery.paste(
            thumb, (x + (384 - thumb.width) // 2, y + (275 - thumb.height) // 2)
        )
        draw.text((x, y + 280), caption[i], font=face, fill="#e3d5bc")
        if i < 4:
            core = np.asarray(img.resize((752, 752), Image.Resampling.LANCZOS))
            atlas.paste(
                Image.fromarray(np.pad(core, ((8, 8), (8, 8), (0, 0)), mode="edge")),
                ((i % 2) * 768, (i // 2) * 768),
            )
    atlas.save(resources / "UpperGlass.png", optimize=True)

    # One sky scan faces the club and the other the railway. Cross-fade near their
    # junctions and bind all longitudes to a common zenith to remove polar spokes.
    sky = np.hstack(
        (np.asarray(source["air-proof"]), np.asarray(source["air"]))
    ).astype(float)
    w = sky.shape[1]
    for seam in (0, w // 2):
        for d in range(112):
            left, right = (seam - d - 1) % w, (seam + d) % w
            midpoint = (sky[:, left] + sky[:, right]) * 0.5
            weight = (1 - d / 112) ** 2
            sky[:, left] += weight * (midpoint - sky[:, left])
            sky[:, right] += weight * (midpoint - sky[:, right])
    for y in range(96):
        sky[y] += ((1 - y / 96) ** 2) * (sky[y].mean(axis=0) - sky[y])
    sky = np.roll(sky, -w // 4, axis=1)
    air = Image.fromarray(np.uint8(np.clip(sky, 0, 255))).resize(
        (2048, 512), Image.Resampling.LANCZOS
    )
    air.save(resources / "EveningAir.png", optimize=True)
    gallery.save(HERE / "index.jpg", quality=90, optimize=True)

    log = []
    for i, (name, w, h, _) in enumerate(SPECS):
        events = dict(json.loads((args.work / (name + ".json")).read_text()))
        start, end = events["execution_start"], events["execution_success"]
        log.append(
            {
                "name": name,
                "seed": 2026112290 + i,
                "pixels": [w, h],
                "prompt_id": end["prompt_id"],
                "seconds": (end["timestamp"] - start["timestamp"]) / 1000,
                "sha256": hashlib.sha256(
                    (args.work / (name + ".png")).read_bytes()
                ).hexdigest(),
            }
        )
    results = {
        name: hashlib.sha256((resources / (name + ".png")).read_bytes()).hexdigest()
        for name in ("UpperGlass", "EveningAir")
    }
    (HERE / "runs.json").write_text(
        json.dumps({"generation": log, "textures": results}, indent=2) + "\n",
        encoding="utf8",
    )


if __name__ == "__main__":
    main()
