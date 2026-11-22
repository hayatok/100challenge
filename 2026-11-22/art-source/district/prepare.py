"""Finish approved MOSS output, copy workspace textures, and compose the art index."""
import argparse
import hashlib
import json
import os
import random
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter
from render import HERE, SPECS

ROOT = HERE.parents[1]
ASSETS = ROOT / "Game/Assets/Resources/KinseiDistrictArt"
PLATES = HERE / "plates"
PRINTS = {
    "lotus-float": "メロンフロート",
    "lotus-voucher": "喫茶の回数券",
    "needle-sleeve": "店頭の自家盤",
    "needle-return": "返却棚の琺瑯札",
    "relay-test": "中継の試験画",
    "relay-card": "受像カード",
}
ROWS = [
    [("lotus-open", "一杯ずつ淹れる"), ("lotus-close", "最後の皿を重ねる"), ("lotus-float", PRINTS["lotus-float"]), ("lotus-voucher", PRINTS["lotus-voucher"])],
    [("needle-open", "貸盤を棚で探す"), ("needle-close", "針台の埃を払う"), ("needle-sleeve", PRINTS["needle-sleeve"]), ("needle-return", PRINTS["needle-return"])],
    [("relay-open", "窓口で受け取る"), ("relay-close", "窓口を閉じる"), ("relay-test", PRINTS["relay-test"]), ("relay-card", PRINTS["relay-card"])],
    [("contact-wear", "摩耗した端子"), ("patch-room", "交換室の手順"), ("greenroom", "金星の楽屋"), ("lane-round", "町内を回る朝")],
]


def save_if_changed(path, data):
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def clean_float(path):
    # Rebuild the stock beneath three pieces of invented small print from bare areas
    # on the same sheet. Soft joins preserve the paper grain around the repaired ink.
    image = Image.open(path).convert("RGB")
    for (x, y), (sx, sy), (width, height) in [
        ((59, 379), (541, 359), (183, 164)),
        ((208, 932), (36, 925), (349, 39)),
        ((407, 987), (31, 987), (339, 31)),
    ]:
        patch = image.crop((sx, sy, sx + width, sy + height))
        if y == 932:
            # Tile blank paper from the left of the printed footer.
            paper = image.crop((53, 931, 201, 970))
            for offset in (0, 148, 296):
                patch.paste(paper, (offset, 0))
        mask = Image.new("L", patch.size)
        ImageDraw.Draw(mask).rectangle((3, 3, width-4, height-4), fill=255)
        image.paste(patch, (x, y), mask.filter(ImageFilter.GaussianBlur(2)))
    fonts = Path(os.environ["WINDIR"]) / "Fonts"
    draw = ImageDraw.Draw(image)
    serif = ImageFont.truetype(str(fonts/"yumin.ttf"), 29)
    for i, line in enumerate(("メロン", "フロート")):
        draw.text((151, 415+i*45), line, font=serif, anchor="ma", fill="#187970")
    footer = ImageFont.truetype(str(fonts/"yumin.ttf"), 24)
    draw.text((384, 935), "純喫茶 ロータス", font=footer, anchor="ma", fill="#217970")
    buf = BytesIO()
    image.save(buf, "PNG")
    return buf.getvalue()

def dispatch_signs(image):
    # The location photo has four wall notices. Typeset the actual dispatch wording
    # inside the existing frames, retaining their tiny shadows and uneven margins.
    notices = [
        ((364, 156, 466, 204), (161, 159, 145), [("受付窓口", 17), ("共同送像所", 8)]),
        ((539, 135, 636, 211), (159, 148, 130), [("本日の受付", 12), ("終了", 24)]),
        ((766, 77, 875, 161), (162, 157, 140), [("宵待町", 11), ("共同送像所", 18), ("回線取扱室", 9)]),
        ((551, 310, 619, 379), (164, 150, 128), [("当番表", 14), ("昼　二番", 9), ("夜　一番", 9)]),
    ]
    font = str(Path(os.environ["WINDIR"])/"Fonts"/"meiryo.ttc")
    rng = random.Random(1222)
    for (x0, y0, x1, y1), stock, lines in notices:
        width, height = x1-x0, y1-y0
        paper = Image.new("RGB", (width, height))
        pixels = []
        for y in range(height):
            for x in range(width):
                shade = rng.randrange(-5, 6) - round(5*(1-y/height)) + round(3*x/width)
                pixels.append(tuple(v + shade for v in stock))
        paper.putdata(pixels)
        draw = ImageDraw.Draw(paper)
        row = height / (len(lines)+1)
        for j, (line, size) in enumerate(lines):
            ink = (101, 39, 31) if x0 == 539 else (42, 43, 36)
            draw.text((width/2, (j+1)*row), line, anchor="mm", fill=ink, font=ImageFont.truetype(font, size))
        image.paste(paper.filter(ImageFilter.GaussianBlur(.35)), (x0, y0))
    return image

def affix(image, label, tl, tr, bl):
    """Project a rectangular print along the two perspective axes at the top-left."""
    ax, ay = tr[0]-tl[0], tr[1]-tl[1]
    bx, by = bl[0]-tl[0], bl[1]-tl[1]
    det = ax*by-ay*bx
    a, b = label.width*by/det, -label.width*bx/det
    d, e = -label.height*ay/det, label.height*ax/det
    inverse = (a, b, -a*tl[0]-b*tl[1], d, e, -d*tl[0]-e*tl[1])
    layer = label.convert("RGBA").transform(image.size, Image.Transform.AFFINE, inverse, Image.Resampling.BICUBIC)
    image.paste(layer, mask=layer.getchannel("A").filter(ImageFilter.GaussianBlur(.45)))


def street_signs(image):
    # The production sleeve doubles as the record carried along the round.
    sleeve = Image.open(ASSETS/"needle-sleeve.png").convert("RGB")
    from PIL import ImageEnhance
    affix(image, ImageEnhance.Brightness(sleeve).enhance(.57), (174, 415), (343, 434), (179, 552))
    fonts = Path(os.environ["WINDIR"])/"Fonts"
    signs = [
        ((128,81),(459,72),(129,120), (330,40), (41,53,40), (182,170,143), "LOTUS COFFEE", 28),
        ((764,52),(1036,44),(765,130), (272,78), (157,152,140), (50,44,38), "貸レコード  針音堂", 24),
        ((1084,553),(1169,563),(1083,615), (86,62), (67,67,63), (172,169,151), "営業中", 19),
        ((1112,160),(1139,158),(1112,344), (28,184), (70,53,40), (187,165,125), "貸盤受付", 17),
    ]
    for tl,tr,bl,size,ground,ink,words,pt in signs:
        paper = Image.new("RGB",size)
        rng = random.Random(pt)
        pixels = []
        for y in range(size[1]):
            for x in range(size[0]):
                noise = rng.randrange(-4,5) + round(5*x/size[0]) - round(6*(1-y/size[1]))
                pixels.append(tuple(max(0,v+noise) for v in ground))
        paper.putdata(pixels)
        draw = ImageDraw.Draw(paper)
        font = ImageFont.truetype(str(fonts/"meiryob.ttc"),pt)
        if size[1] > size[0]:
            for i, ch in enumerate(words):
                draw.text((size[0]/2, 32+i*37), ch, font=font, fill=ink, anchor="mm")
        else:
            draw.text((size[0]/2, size[1]/2), words, font=font, fill=ink, anchor="mm")
        affix(image, paper.filter(ImageFilter.GaussianBlur(.7)), tl,tr,bl)
    return image

def prepare(name, work):
    path = work / (name + ".png")
    target = ASSETS / path.name if name in PRINTS else PLATES / (name + ".jpg")
    if name in PRINTS:
        data = clean_float(path) if name == "lotus-float" else path.read_bytes()
        save_if_changed(target, data)
    else:
        with Image.open(path) as image:
            output = BytesIO()
            plate = image.convert("RGB")
            if name == "relay-close":
                plate = dispatch_signs(plate)
            elif name == "lane-round":
                plate = street_signs(plate)
            plate.save(output, "JPEG", quality=92, subsampling=0, optimize=True)
            save_if_changed(target, output.getvalue())
    return target


def index():
    sheet = Image.new("RGB", (1600, 1310), "#1d2424")
    draw = ImageDraw.Draw(sheet)
    fonts = Path(os.environ["WINDIR"]) / "Fonts"
    heading = ImageFont.truetype(str(fonts / "yumin.ttf"), 44)
    label = ImageFont.truetype(str(fonts / "meiryo.ttc"), 20)
    draw.text((28, 8), "宵待町　通りの仕事", font=heading, fill="#f6dfb4")
    draw.text((1170, 38), "店の一日と、使い込まれた道具", font=label, fill="#e1c492")
    for row, group in enumerate(ROWS):
        for col, (name, title) in enumerate(group):
            x, y = 28 + 391 * col, 92 + row * 304
            path = ASSETS / (name+".png") if name in PRINTS else PLATES / (name+".jpg")
            with Image.open(path) as image:
                image.thumbnail((370, 247), Image.Resampling.LANCZOS)
                sheet.paste(image, (x+(370-image.width)//2, y+(247-image.height)//2))
            draw.text((x+2, y+251), title, font=label, fill="#e9d8b7")
    sheet.save(HERE/"index.jpg", quality=90, optimize=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("work", type=Path)
    parser.add_argument("names", nargs="*")
    args = parser.parse_args()
    PLATES.mkdir(exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    ledger = []
    for i, (name, width, height, _) in enumerate(SPECS):
        if args.names and name not in args.names:
            continue
        path = prepare(name, args.work)
        events = dict(json.loads((args.work/(name+".json")).read_text()))
        start, end = events["execution_start"], events["execution_success"]
        ledger.append(dict(name=name, seed=2026112230+i, generated_pixels=[width,height],
                           prompt_id=end["prompt_id"], seconds=(end["timestamp"]-start["timestamp"])/1000,
                           source_sha256=hashlib.sha256((args.work/(name+".png")).read_bytes()).hexdigest(),
                           file=path.relative_to(ROOT).as_posix(), sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    if not args.names:
        index()
        (HERE/"runs.json").write_text(json.dumps(ledger, indent=2)+"\n", encoding="utf8")


if __name__ == "__main__":
    main()




