from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def make_ticket():
    width, height = 480, 704
    random = np.random.default_rng(101)
    grain = random.normal(0, 3.6, (height, width, 1))
    rgb = np.clip(np.array([227, 213, 180]) + grain, 0, 255).astype('uint8')
    paper = Image.fromarray(rgb)
    draw = ImageDraw.Draw(paper)
    ink = (122, 45, 48)
    fontdir = Path('C:/Windows/Fonts')

    def put(y, words, size, font='yumin.ttf'):
        face = ImageFont.truetype(str(fontdir / font), size)
        draw.text((width // 2, y), words, font=face, fill=ink, anchor='mm')

    draw.rounded_rectangle((20, 18, 460, 685), radius=12, outline=ink, width=4)
    draw.rectangle((30, 28, 450, 675), outline=ink, width=1)
    put(94, '宵待町興行', 41)
    draw.line((66, 151, 414, 151), fill=ink, width=2)
    put(231, '金　星', 84)
    put(345, '専 属 興 行', 44)
    put(416, '指定席　一名', 31)
    for x in range(34, 445, 16):
        draw.line((x, 489, x+8, 489), fill=ink, width=2)
    put(540, '開場第一号', 29)
    put(609, '0001', 75, 'georgia.ttf')
    target = Path(__file__).resolve().parents[2] / 'Game/Assets/Resources/KinseiPrintworks/FirstTicket.png'
    paper.save(target, optimize=True)


if __name__ == '__main__':
    make_ticket()
