"""Prepare selected archive plates and the four Unity textures after generate.py."""
import argparse
import os
from io import BytesIO
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from generate import HERE, SPECS

RUNTIME = HERE.parents[1] / "Game/Assets/Resources/KinseiAtelier"
REFERENCES = HERE / "plates"
PRINTS = {"camellia", "broadcast", "chanteuse", "lotus-sign"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_index():
    rows = [
        [("makabe", "真壁"), ("tatsu", "辰"), ("kaji", "梶"), ("otouto", "梶の弟")],
        [("elder", "兄貴分"), ("swatches", "衣裳の生地"), ("relay", "中継鏡"), ("assistance", "弟に肩を貸す")],
        [("facade", "金星の入口"), ("daylight", "開店前"), ("evening", "営業中"), ("table-read", "辰と梶の卓")],
        [("camellia", "椿の漆絵"), ("broadcast", "中継番組の印刷物"), ("chanteuse", "専属歌手の写真"), ("lotus-sign", "系列店の看板")],
    ]
    fonts = Path(os.environ["WINDIR"]) / "Fonts"
    heading = ImageFont.truetype(str(fonts / "yumin.ttf"), 46)
    label = ImageFont.truetype(str(fonts / "meiryo.ttc"), 21)
    sheet = Image.new("RGB", (1600, 1304), "#211e1e")
    draw = ImageDraw.Draw(sheet)
    draw.text((30, 14), "宵待町　金星美術部", font=heading, fill="#efdbb3")
    draw.text((1224, 42), "設定写真と店内原画　／　16点", font=label, fill="#ede1cf")
    for row, entries in enumerate(rows):
        y = 96 + 302 * row
        for column, (name, caption) in enumerate(entries):
            x = 28 + column * 391
            path = RUNTIME / (name + ".png") if name in PRINTS else REFERENCES / (name + ".jpg")
            with Image.open(path) as picture:
                picture.thumbnail((370, 244), Image.Resampling.LANCZOS)
                sheet.paste(picture, (x + (370 - picture.width) // 2, y + (244 - picture.height) // 2))
            draw.text((x + 2, y + 251), caption, font=label, fill="#eadfc9")
    sheet.save(HERE / "index.jpg", quality=90, optimize=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("work", type=Path)
    args = parser.parse_args()
    REFERENCES.mkdir(exist_ok=True)
    RUNTIME.mkdir(parents=True, exist_ok=True)
    catalog = []
    for index, (name, width, height, _) in enumerate(SPECS):
        source = args.work / (name + ".png")
        history = json.loads((args.work / (name + ".json")).read_text())
        events = dict(history["events"])
        elapsed = (events["execution_success"]["timestamp"] - events["execution_start"]["timestamp"]) / 1000
        target = RUNTIME / source.name if name in PRINTS else REFERENCES / (name + ".jpg")
        output = BytesIO()
        with Image.open(source) as image:
            if name == "broadcast":
                image.crop((0, 0, 768, 866)).save(output, format="PNG")
            elif name == "lotus-sign":
                image.transform((960, 328), Image.Transform.QUAD, (48, 84, 22, 416, 1011, 469, 987, 156), Image.Resampling.BICUBIC).save(output, format="PNG")
            elif name in PRINTS:
                output.write(source.read_bytes())
            else:
                image.convert("RGB").save(output, format="JPEG", quality=92, subsampling=0, optimize=True)
        data = output.getvalue()
        if not target.exists() or target.read_bytes() != data:
            target.write_bytes(data)
        catalog.append(dict(name=name, seed=1973112400 + index, generated_pixels=[width, height],
                            prompt_id=history["prompt_id"], seconds=elapsed, source_sha256=digest(source),
                            file=target.relative_to(HERE.parents[1]).as_posix(), sha256=digest(target)))
    make_index()
    (HERE / "runs.json").write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf8")


if __name__ == "__main__":
    main()


