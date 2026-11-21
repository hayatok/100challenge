"""Assemble the three production atlases and their Unity bottom-left UV tables."""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

from render import HERE, SPECS

ASSETS = HERE.parents[1] / "Resources/KinseiPrintworks"
if (HERE.parents[1] / "Game/Assets/Resources").is_dir():
    ASSETS = HERE.parents[1] / "Game/Assets/Resources/KinseiPrintworks"
FONTS = Path(os.environ["WINDIR"]) / "Fonts"
ALBUMS = [
    ("singer", "夜の椿", "金星専属歌手の夕べ", "#ead5b5", "#3d2429"),
    ("trio", "三人の乾杯", "針音堂ジャズ・トリオ", "#f4cf85", "#222c3c"),
    ("folk", "河内の輪", "宵待民謡採集", "#efe1b7", "#3d342c"),
    ("forty", "四十軒放送", "共同送像所・公開録音", "#ebdfb4", "#30372b"),
    ("percussion", "打面", "打楽器のための小品", "#252529", "#e6bd49"),
    ("harbor", "波止場まで", "大阪港器楽集", "#e4d7a7", "#334a4b"),
    ("guitar", "六弦便り", "午後の独奏", "#f0d4a0", "#534239"),
    ("nighttrain", "終電の窓", "夜行小品集", "#e3d8bf", "#292b48"),
]
BOTTLES = [
    ("amber", "夕凪", "AMBER WHISKY", (58, 220, 966, 804), "#ede2bd", "#583b29"),
    ("gin", "月梢", "JUNIPER GIN", (208, 48, 816, 976), "#dce5df", "#183b53"),
    ("plum", "花暦", "PLUM LIQUEUR", (72, 120, 952, 904), "#e8cfac", "#5c2431"),
    ("bitters", "苦橙", "CITRUS BITTERS", (184, 44, 840, 980), "#ded0a3", "#433c2b"),
]
STATION = ["meter", "line", "schedule", "ticket"]
PICKS = {"singer": "singer-proof", "gin": "gin"}


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


def txt(draw, x, y, value, size, ink, style="meiryo.ttc", anchor="mm"):
    draw.text((x, y), value, font=font(style, size), fill=ink, anchor=anchor)


def pad(image, w, h):
    # 8px edge duplication shields every neighbouring material at smaller mip levels.
    core = image.resize((w - 16, h - 16), Image.Resampling.LANCZOS)
    padded = Image.new(image.mode, (w, h))
    padded.paste(core, (8, 8))
    padded.paste(core.crop((0, 0, 1, h - 16)).resize((8, h - 16)), (0, 8))
    padded.paste(core.crop((w - 17, 0, w - 16, h - 16)).resize((8, h - 16)), (w - 8, 8))
    padded.paste(padded.crop((0, 8, w, 9)).resize((w, 8)), (0, 0))
    padded.paste(padded.crop((0, h - 9, w, h - 8)).resize((w, 8)), (0, h - 8))
    return padded


def jacket(base, i):
    key, title, credit, ink, paper = ALBUMS[i]
    draw = ImageDraw.Draw(base)
    if key == "singer":
        draw.rectangle((48, 45, 110, 365), fill=paper)
        for j, char in enumerate(title):
            txt(draw, 79, 100 + 95 * j, char, 47, ink, "yumin.ttf")
    elif key in ("folk", "guitar"):
        draw.rectangle((43, 0, 145, 1024), fill=paper)
        for j, char in enumerate(title):
            txt(draw, 94, 125 + 98 * j, char, 59, ink, "yumin.ttf")
        txt(draw, 94, 946, "LP", 27, ink, "georgia.ttf")
    elif key == "trio":
        draw.rectangle((0, 0, 1024, 120), fill=paper)
        draw.rectangle((0, 119, 419, 272), fill=paper)
        txt(draw, 44, 63, title, 67, ink, "meiryob.ttc", "lm")
        txt(draw, 42, 180, credit, 25, ink, "meiryo.ttc", "lm")
        txt(draw, 45, 230, "HARIONDO SESSIONS", 18, ink, "georgia.ttf", "lm")
    elif key == "forty":
        draw.rectangle((0, 847, 1024, 1024), fill=paper)
        txt(draw, 44, 916, title, 60, ink, "meiryob.ttc", "lm")
        txt(draw, 47, 985, credit, 22, ink, "meiryo.ttc", "lm")
    elif key == "percussion":
        draw.rectangle((0, 0, 1024, 118), fill=paper)
        txt(draw, 41, 57, title, 57, ink, "meiryob.ttc", "lm")
        txt(draw, 981, 63, credit, 24, ink, "meiryo.ttc", "rm")
    else:
        draw.rectangle((0, 890, 1024, 1024), fill=paper)
        txt(draw, 54, 953, title, 61, ink, "yumin.ttf", "lm")
        txt(draw, 966, 961, credit, 25, ink, "meiryo.ttc", "rm")
    return base


def spirits(base, i):
    key, title, english, box, cream, ink = BOTTLES[i]
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    if key == "bitters":
        base = base.crop((205, 376, 821, 789))
    face = ImageOps.fit(base, (w, h), Image.Resampling.LANCZOS)
    mask = Image.new("L", (w, h))
    md = ImageDraw.Draw(mask)
    if key == "plum":
        md.ellipse((0, 0, w - 1, h - 1), fill=255)
    elif key == "bitters":
        md.polygon(
            [
                (0, 42),
                (w // 2, 0),
                (w - 1, 42),
                (w - 1, int(h * 0.77)),
                (w // 2, h - 1),
                (0, int(h * 0.77)),
            ],
            fill=255,
        )
    else:
        md.rounded_rectangle((0, 0, w - 1, h - 1), radius=36 if key == "amber" else 82, fill=255)
    d = ImageDraw.Draw(face)
    cy = int(h * {"amber": 0.785, "gin": 0.69, "plum": 0.70, "bitters": 0.69}[key])
    d.rounded_rectangle(
        (int(w * 0.16), cy - 46, int(w * 0.84), cy + 64), radius=5, fill=cream, outline=ink, width=3
    )
    txt(d, w // 2, cy - 10, title, 50, ink, "yumin.ttf")
    txt(d, w // 2, cy + 40, english, 19, ink, "georgiab.ttf")
    face.putalpha(mask.filter(ImageFilter.GaussianBlur(0.55)))
    output = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    output.paste(face, (x0, y0))
    return output


def station(base, key):
    d = ImageDraw.Draw(base)
    if key == "meter":
        # Logarithmic dB spacing displayed by a rectified, linear moving coil.
        def point(db, r):
            normalized = (10 ** (db / 20) - 0.1) / (10 ** (3 / 20) - 0.1)
            a = math.radians(-43 + 86 * normalized)
            return (512 + math.sin(a) * r, 720 - math.cos(a) * r)

        for lo, hi, color in [(-20, 0, "#333127"), (0, 3, "#b43a29")]:
            d.line([point(lo + (hi - lo) * j / 120, 574) for j in range(121)], fill=color, width=8)
        for n in [-20, -15, -10, -7, -5, -3, -2, -1, 0, 1, 2, 3]:
            color = "#b43a29" if n > 0 else "#302d29"
            d.line([point(n, 574), point(n, 598)], fill=color, width=4)
            label = str(n) if n <= 0 else "+" + str(n)
            txt(d, *point(n, 624), label, 20, color, "arial.ttf")
        txt(d, 512, 305, "VU", 65, "#393629", "georgia.ttf")
        txt(d, 512, 388, "共同送像所　変調監視", 25, "#4e493a")
        txt(d, 512, 433, "0 VU  =  +4 dBu", 17, "#575342", "arial.ttf")
    elif key == "line":
        d.rounded_rectangle((46, 45, 978, 467), radius=15, outline="#cdbb78", width=4)
        txt(d, 80, 107, "宵待町共同送像所", 29, "#d6cca7", "meiryo.ttc", "lm")
        txt(d, 80, 246, "金星  ─  第四線", 69, "#f1e3b4", "meiryob.ttc", "lm")
        d.line((84, 327, 933, 327), fill="#ad9b5b", width=3)
        txt(d, 85, 389, "舞 台 か ら 客 席 へ", 30, "#d0c395", "yumin.ttf", "lm")
    elif key == "schedule":
        # The large right-hand print field covers any incidental generated letterforms.
        d.rectangle((325, 45, 956, 470), fill="#ece1bd")
        txt(d, 354, 103, "きょうの午後便", 47, "#623b36", "yumin.ttf", "lm")
        for j, (time, title) in enumerate(
            [("13:00", "町内だより"), ("14:30", "レコードの時間"), ("16:00", "金星から一曲")]
        ):
            y = 205 + j * 83
            d.line((352, y - 34, 919, y - 34), fill="#b8a788", width=2)
            txt(d, 354, y, time, 32, "#263d4a", "georgia.ttf", "lm")
            txt(d, 525, y, title, 31, "#313d40", "meiryo.ttc", "lm")
    else:
        d.rounded_rectangle((267, 78, 844, 426), radius=6, fill="#edddbc", outline="#ac7952", width=4)
        txt(d, 555, 151, "宵 待 町", 30, "#82513a", "yumin.ttf")
        txt(d, 555, 245, "昭和百年祭", 65, "#71392e", "yumin.ttf")
        txt(d, 555, 349, "記 念 入 場 券", 30, "#75533d")
    return base


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("work", type=Path)
    args = parser.parse_args()
    ASSETS.mkdir(parents=True, exist_ok=True)
    layout = {}
    plates = []
    for group, names, cols, tilew, tileh in [
        ("Sleeves", [v[0] for v in ALBUMS], 4, 1024, 1024),
        ("Bottles", [v[0] for v in BOTTLES], 2, 1024, 1024),
        ("Station", STATION, 2, 1024, 512),
    ]:
        rows = len(names) // cols
        aw, ah = cols * tilew, rows * tileh
        atlas = Image.new("RGBA" if group == "Bottles" else "RGB", (aw, ah))
        frames = []
        for i, name in enumerate(names):
            master = PICKS.get(name, name)
            with Image.open(args.work / (master + ".png")) as raw:
                base = raw.convert("RGB")
            if group == "Sleeves":
                frame = jacket(base, i)
            elif group == "Bottles":
                frame = spirits(base, i)
            else:
                frame = station(base, name)
            col, row = i % cols, i // cols
            x, y = col * tilew, row * tileh
            atlas.paste(pad(frame, tilew, tileh), (x, y))
            bounds = (x + 8, y + 8, x + tilew - 8, y + tileh - 8)

            def uv(rect, aw=aw, ah=ah):
                l, t, r, b = rect
                return [
                    round(l / aw, 8),
                    round(1 - b / ah, 8),
                    round((r - l) / aw, 8),
                    round((b - t) / ah, 8),
                ]

            record = {
                "key": name,
                "master": master,
                "column": col,
                "row_from_top": row,
                "uv": uv(bounds),
            }
            if group == "Bottles":
                box = BOTTLES[i][3]
                record["tight_uv"] = uv(
                    (
                        bounds[0] + box[0] * (tilew - 16) / 1024,
                        bounds[1] + box[1] * (tileh - 16) / 1024,
                        bounds[0] + box[2] * (tilew - 16) / 1024,
                        bounds[1] + box[3] * (tileh - 16) / 1024,
                    )
                )
            frames.append(record)
            plates.append((group, name, frame))
        dest = ASSETS / (group + ".png")
        atlas.save(dest, optimize=True)
        layout[group] = {
            "pixels": [aw, ah],
            "sha256": hashlib.sha256(dest.read_bytes()).hexdigest(),
            "cells": frames,
        }
    (HERE / "atlas.json").write_text(json.dumps(layout, indent=2) + "\n", encoding="utf8")
    index = Image.new("RGB", (1480, 1176), "#292624")
    d = ImageDraw.Draw(index)
    txt(d, 36, 42, "宵待町　町の印刷所", 45, "#e8d4ab", "yumin.ttf", "lm")
    txt(d, 1444, 44, "ジャケット・瓶の銘柄・共同送像所の印刷物", 21, "#dbcba9", "meiryo.ttc", "rm")
    for i, (g, n, im) in enumerate(plates):
        col, row = i % 4, i // 4
        x, y = 34 + col * 363, 88 + row * 271
        preview = im.copy()
        preview.thumbnail((336, 223), Image.Resampling.LANCZOS)
        index.paste(
            preview,
            (x + (336 - preview.width) // 2, y + (223 - preview.height) // 2),
            preview.getchannel("A") if preview.mode == "RGBA" else None,
        )
        caption = (
            ALBUMS[i][1]
            if i < 8
            else BOTTLES[i - 8][1]
            if i < 12
            else ["VU メーター盤", "第四線の回線札", "午後の番組表", "昭和百年祭の保存切符"][i - 12]
        )
        txt(d, x + 10, y + 242, caption, 20, "#e8dabe", "meiryo.ttc", "lm")
    index.save(HERE / "index.jpg", quality=91, optimize=True)
    used = {record["master"] for group in layout.values() for record in group["cells"]}
    runs = []
    for i, (name, w, h, _) in enumerate(SPECS):
        events = dict(json.loads((args.work / (name + ".json")).read_text()))
        start, end = events["execution_start"], events["execution_success"]
        runs.append(
            {
                "name": name,
                "picked": name in used,
                "seed": 2026112260 + i,
                "pixels": [w, h],
                "prompt_id": end["prompt_id"],
                "seconds": (end["timestamp"] - start["timestamp"]) / 1000,
                "sha256": hashlib.sha256((args.work / (name + ".png")).read_bytes()).hexdigest(),
            }
        )
    (HERE / "runs.json").write_text(json.dumps(runs, indent=2) + "\n", encoding="utf8")


if __name__ == "__main__":
    main()
