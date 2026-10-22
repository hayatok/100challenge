#!/usr/bin/env python3
"""Author the combat sprite atlases as original, grid-aligned SVG artwork.

No source image is read or raster image written. Each silhouette, fold, limb and
prop below is a vector shape on a one-pixel lattice. Godot imports these SVGs.
"""

from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "game/assets/art"
INK = "11192b"
DEEP = "20263c"
SHADOW = "34364e"
MID = "55526b"
PAPER = "f4ecce"
CREAM = "d3c8b0"
STONE = "8f9b91"
GOLD = "dbb66e"
BRASS = "91704c"
BLUE = "91e7eb"
CYAN = "48a6bc"
RED = "f1848c"
PURPLE = "73547c"
LILAC = "ab80b1"

# Shared ordering is also declared in PixelActors.ANIMATIONS.
ANIMATIONS = [("idle", 4), ("walk", 6), ("cast", 4), ("hit", 2),
              ("warning", 4), ("rush", 4), ("recover", 3),
              ("arrival", 4), ("death", 5)]


def stair(points):
    """Turn authored diagonals into orthogonal one-pixel vector stair steps."""
    result = [tuple(points[0])]
    for end in list(points[1:]) + [points[0]]:
        start = result[-1]
        dx, dy = end[0] - start[0], end[1] - start[1]
        steps = max(abs(dx), abs(dy))
        for i in range(1, steps + 1):
            x = start[0] + round(dx * i / steps)
            y = start[1] + round(dy * i / steps)
            old = result[-1]
            if old[0] != x and old[1] != y:
                result.append((x, old[1]))
            if result[-1] != (x, y):
                result.append((x, y))
    return " ".join(f"{x},{y}" for x, y in result)


class Art:
    def __init__(self):
        self.parts = []

    def group(self, x=0, y=0, attributes=""):
        self.parts.append(f'<g transform="translate({int(x)} {int(y)})" {attributes}>')

    def end(self):
        self.parts.append("</g>")

    def p(self, points, color, edge=INK):
        stroke = f' stroke="#{edge}" stroke-width="2" stroke-linejoin="miter"' if edge else ""
        self.parts.append(f'<polygon points="{stair(points)}" fill="#{color}"{stroke}/>')

    def r(self, x, y, w, h, color):
        if w > 0 and h > 0:
            self.parts.append(f'<rect x="{int(x)}" y="{int(y)}" width="{int(w)}" height="{int(h)}" fill="#{color}"/>')

    def star(self, x, y, color=BLUE, radius=3):
        self.r(x, y - radius, 1, radius * 2 + 1, color)
        self.r(x - radius, y, radius * 2 + 1, 1, color)
        self.r(x, y, 1, 1, PAPER)

    def eye(self, x, y, color=RED, blink=False):
        self.r(x, y, 4, 1 if blink else 2, color)
        if not blink:
            self.r(x + 2, y, 1, 1, PAPER)

    def text(self):
        return "".join(self.parts)


def movement(animation, frame):
    # Leg positions are individually drawn; the body itself never rocks/rotates.
    if animation == "walk":
        stride = [-3, -1, 2, 3, 1, -2][frame]
        return stride, [0, -1, -1, 0, -1, -1][frame], [-2, -1, 1, 2, 1, -1][frame]
    if animation == "rush":
        return [-5, 0, 5, 0][frame], -2, [-3, -1, 2, 1][frame]
    if animation == "warning":
        return 0, [0, 1, 2, 2][frame], [0, -1, -2, -2][frame]
    if animation == "recover":
        return 0, [2, 1, 0][frame], [-2, -1, 0][frame]
    if animation == "hit":
        return 0, 1, -2 if frame == 0 else -1
    return 0, [0, -1, 0, 0][frame % 4], [0, 1, 0, -1][frame % 4]


def witch(a, animation, frame):
    step, breath, cloth = movement(animation, frame)
    cast = [0, 5, 11, 3][frame] if animation == "cast" else 0
    hurt = animation == "hit"
    blink = animation == "idle" and frame == 3
    a.group(-2 if hurt and frame == 0 else 0, 0)
    # Two stockings and boots remain visible below the swinging skirt.
    for x, advance, dark in [(28, -step, SHADOW), (36, step, DEEP)]:
        a.p([(x, 46), (x + 5, 46), (x + 5 + advance, 55),
             (x + 7 + advance, 58), (x + 1 + advance, 59), (x - 1 + advance, 56)], dark)
        a.r(x + 1, 48, 2, 4, CREAM)
        a.r(x + 2 + advance, 56, 4, 1, GOLD)
    a.group(0, breath)
    # The back hair and two cape tails have separate silhouettes/offsets.
    a.p([(25, 22), (39, 21), (44, 29), (42, 36), (47 + cloth, 42),
         (39, 42), (37, 37), (23, 40), (17 - cloth, 37), (22, 31)], DEEP)
    a.p([(25, 33), (21, 39), (17 - cloth, 49), (22, 46), (20 - cloth, 53),
         (31, 49), (33, 36)], PURPLE)
    a.p([(37, 33), (41, 36), (44 + cloth, 47), (49 + cloth, 51),
         (42, 50), (39, 46), (38, 52), (34, 44)], SHADOW)
    a.r(21 - cloth, 45, 2, 3, LILAC)
    # Cream underskirt, purple bodice and asymmetrical gilded skirt folds.
    a.p([(27, 36), (39, 36), (40, 43), (44, 50), (39, 53),
         (36, 51), (33, 54), (30, 51), (26, 53), (22, 50)], CREAM)
    a.p([(28, 31), (37, 30), (40, 36), (37, 40), (40, 46),
         (42, 49), (35, 48), (32, 51), (29, 47), (23, 49), (27, 40)], PURPLE)
    a.p([(30, 35), (34, 34), (35, 40), (33, 48), (30, 45)], MID, None)
    a.r(29, 38, 9, 2, BRASS)
    a.r(31, 38, 3, 2, GOLD)
    a.r(27, 45, 1, 3, GOLD)
    a.r(37, 44, 1, 3, GOLD)
    a.r(25, 50, 4, 1, PAPER)
    a.r(34, 51, 4, 1, PAPER)
    # Far sleeve sways; the near arm visibly raises the spellbook during cast.
    a.p([(27, 32), (23, 34), (22 - cloth, 40), (25, 43),
         (29, 39), (30, 35)], SHADOW)
    a.r(23 - cloth, 39, 3, 2, CREAM)
    a.p([(38, 32), (41, 33 - cast // 2), (44, 35 - cast),
         (47, 34 - cast), (47, 38 - cast), (42, 40 - cast // 2), (38, 38)], PURPLE)
    a.r(44, 34 - cast, 4, 3, "e6bdac")
    # Readable face, fringe and moon ear clasp under the wide cream brim.
    a.group(0, 2)
    a.p([(28, 23), (38, 23), (40, 28), (37, 32), (31, 32), (27, 28)], "e6bdac")
    a.r(29, 28, 2, 1, "bc7b86")
    a.eye(34, 27, LILAC, blink or hurt)
    a.p([(26, 21), (38, 21), (40, 24), (35, 24), (32, 27),
         (31, 24), (28, 28), (26, 30)], DEEP, None)
    a.r(27, 29, 2, 2, GOLD)
    a.end()
    # Hat tip bends independently of the brim; it is never a global tilt.
    tip = cloth if animation in ("walk", "idle", "rush") else -1 if hurt else 0
    a.p([(17, 19), (22, 12), (26, 5), (34 + tip, 3), (39 + tip, 6),
         (35 + tip, 7), (33, 10), (38, 16), (43, 20), (38, 23), (24, 23)], CREAM)
    a.p([(22, 17), (26, 9), (32 + tip, 5), (32, 10), (35, 15),
         (37, 18), (28, 20)], PAPER, None)
    a.p([(19, 18), (27, 17), (38, 17), (42, 20), (36, 23), (24, 23)], PURPLE)
    a.r(23, 19, 13, 1, GOLD)
    a.p([(8, 22), (17, 19), (27, 21), (39, 20), (49, 16), (53, 16),
         (50, 21), (43, 25), (31, 27), (19, 26), (10, 24)], CREAM)
    a.p([(11, 22), (19, 21), (27, 23), (40, 22), (49, 18),
         (44, 22), (32, 25), (20, 24)], PAPER, None)
    a.r(17, 25, 7, 1, BRASS)
    a.star(36, 19, GOLD, 2)
    # Gold-bound book has a spine, a page fan and blue bookmark.
    bx, by = 46 + (1 if cast > 5 else 0), 36 - cast
    a.p([(bx - 3, by - 5), (bx + 3, by - 6), (bx + 9, by - 3),
         (bx + 7, by + 6), (bx + 1, by + 4), (bx - 5, by + 4)], BRASS)
    a.p([(bx - 3, by - 4), (bx + 1, by - 3), (bx + 4, by - 5),
         (bx + 8, by - 3), (bx + 6, by + 3), (bx + 1, by + 2), (bx - 4, by + 3)], PAPER, None)
    a.r(bx, by - 2, 1, 5, BRASS)
    a.r(bx + 3, by - 1, 3, 1, CREAM)
    a.r(bx - 3, by, 2, 1, CREAM)
    a.r(bx - 1, by + 3, 1, 4, CYAN)
    if cast > 4:
        a.star(bx + 3, by - 8, BLUE, 3)
        a.star(bx + 9, by - 4, BLUE, 2)
        a.r(bx - 4, by - 9, 1, 2, CYAN)
    a.end()
    a.end()


def hound(a, animation, frame):
    step, breath, tail = movement(animation, frame)
    crouch = 3 if animation == "warning" else 0
    reach = 3 if animation == "rush" else 0
    # Crescent tail and four independently alternating paws.
    a.p([(23, 34), (17, 29), (10, 28 - tail), (8, 22 - tail),
         (5, 28 - tail), (8, 35), (18, 40)], DEEP)
    a.p([(20, 34), (13, 33 - tail), (10, 28 - tail), (13, 35), (20, 38)], MID, None)
    for x, shift, near in [(23, step, False), (37, -step, False),
                            (19, -step, True), (39, step, True)]:
        a.p([(x, 40), (x + 5, 40), (x + shift + 4, 48),
             (x + shift + 7, 51), (x + shift, 52), (x + shift - 1, 48)], SHADOW if near else DEEP)
        a.r(x + shift + 1, 50, 4, 1, CREAM if near else MID)
    a.group(reach, breath + crouch)
    a.p([(17, 34), (23, 29), (32, 28), (39, 31), (45, 35),
         (42, 43), (31, 45), (23, 41), (16, 41)], SHADOW)
    a.p([(22, 31), (31, 29), (36, 33), (32, 36), (22, 37)], MID, None)
    a.p([(36, 29), (42, 25), (44, 19), (47, 27), (51, 27),
         (54, 23), (55, 33), (59, 38), (55, 43), (48, 41), (43, 37), (37, 37)], DEEP)
    a.p([(43, 28), (47, 29), (50, 32), (55, 33), (57, 38),
         (53, 40), (47, 36), (44, 35)], CREAM)
    a.p([(45, 29), (48, 31), (48, 34), (51, 36), (53, 38),
         (50, 36), (46, 35)], PAPER, None)
    a.r(47, 32, 3, 2, INK)
    a.r(48, 32, 2, 1, RED)
    a.r(55, 37, 3, 2, INK)
    a.r(49, 38, 1, 2, PAPER)
    if animation in ("cast", "rush"):
        a.p([(50, 40), (56, 40), (55, 44), (51, 42)], "bc7b86")
        a.r(54, 40, 1, 2, PAPER)
    a.end()


def antler(a, x, y, side=1, color=CREAM):
    # Branches are stepped bone shapes, not thin subpixel lines.
    a.group(x, y)
    if side < 0:
        a.parts.append('<g transform="translate(12 0) scale(-1 1)">')
    a.p([(0, 22), (5, 17), (7, 10), (6, 4), (8, 1), (10, 10),
         (12, 8), (14, 2), (15, 10), (11, 16), (9, 21), (3, 25)], color)
    a.r(7, 12, 2, 7, PAPER)
    if side < 0:
        a.end()
    a.end()


def charger(a, animation, frame):
    step, breath, tail = movement(animation, frame)
    crouch = 3 if animation == "warning" else 0
    forward = 3 if animation == "rush" else 0
    a.p([(18, 35), (9, 32 - tail), (7, 27 - tail), (6, 37), (16, 43)], DEEP)
    for x, shift, near in [(22, step, False), (38, -step, False), (16, -step, True), (39, step, True)]:
        a.p([(x, 42), (x + 7, 41), (x + shift + 6, 50),
             (x + shift + 7, 55), (x + shift - 1, 55), (x + shift, 49)], SHADOW if near else DEEP)
        a.r(x + shift, 52, 6, 3, BRASS)
        a.r(x + shift + 1, 52, 4, 1, GOLD)
    a.group(forward, breath + crouch)
    a.p([(12, 33), (18, 28), (30, 27), (41, 31), (46, 39),
         (41, 46), (23, 46), (13, 42)], SHADOW)
    a.p([(18, 29), (30, 28), (36, 31), (33, 35), (23, 35), (19, 40), (15, 38)], STONE)
    a.p([(22, 30), (27, 30), (28, 33), (25, 33), (23, 37), (21, 37)], CREAM, None)
    a.p([(33, 31), (43, 28), (50, 31), (54, 40), (51, 47),
         (45, 48), (40, 43), (35, 42)], DEEP)
    a.p([(41, 29), (46, 30), (49, 34), (48, 39), (52, 43),
         (49, 46), (44, 42), (42, 37), (38, 35)], CREAM)
    a.r(44, 35, 4, 2, INK)
    a.r(45, 35, 3, 1, RED)
    a.r(48, 43, 4, 2, INK)
    a.r(30, 36, 2, 6, RED)
    a.r(28, 38, 5, 1, RED)
    a.r(34, 40, 2, 3, RED)
    # Horns open a unique, wide silhouette above the low quadruped body.
    antler(a, 30, 6 + (2 if crouch else 0), -1)
    antler(a, 40, 5 + (2 if crouch else 0))
    a.r(37, 29, 2, 3, GOLD)
    a.end()


def cloak(a, left, top, width, bottom, wave, color=SHADOW):
    a.p([(left + width // 3, top), (left + width * 2 // 3, top),
         (left + width - 3, top + 11), (left + width + wave, bottom - 3),
         (left + width - 4, bottom - 6), (left + width - 7, bottom),
         (left + width // 2, bottom - 4), (left + 7, bottom + 1),
         (left + 8, bottom - 5), (left - wave, bottom - 1), (left + 4, top + 12)], color)
    a.p([(left + width // 3, top + 9), (left + width // 2, top + 10),
         (left + 11, bottom - 6), (left + 5, bottom - 2)], MID, None)


def archer(a, animation, frame):
    step, breath, cloth = movement(animation, frame)
    draw = ([1, 3, 6, 8][frame] if animation == "warning" else
            [6, 8, 0, 1][frame] if animation == "cast" else 0)
    for x, shift in [(28, -step), (36, step)]:
        a.p([(x, 46), (x + 4, 46), (x + shift + 4, 56),
             (x + shift + 7, 58), (x + shift, 59)], DEEP)
        a.r(x + shift + 1, 56, 3, 1, BRASS)
    a.group(0, breath)
    a.p([(22, 22), (19, 15), (21, 9), (28, 5), (25, 12), (28, 20)], BRASS)
    a.r(20, 11, 2, 14, GOLD)
    a.r(23, 9, 2, 14, CREAM)
    a.r(26, 7, 2, 15, PAPER)
    cloak(a, 17, 27, 27, 53, cloth, "485a59")
    a.p([(27, 15), (35, 12), (41, 18), (42, 25), (38, 32),
         (24, 30), (22, 23)], "485a59")
    a.p([(30, 17), (36, 18), (39, 23), (36, 29), (28, 27), (27, 22)], INK, None)
    a.p([(29, 19), (36, 19), (38, 24), (34, 29), (30, 26)], CREAM, None)
    a.r(30, 22, 2, 2, RED)
    a.r(35, 22, 2, 2, RED)
    a.r(33, 25, 1, 2, INK)
    a.r(28, 30, 9, 2, BRASS)
    # Bow arm is straight; the string arm draws back to the hood.
    a.p([(37, 32), (42, 32), (46, 35), (51, 34), (51, 38), (44, 39), (37, 36)], "485a59")
    a.r(48, 34, 3, 3, CREAM)
    a.p([(29, 34), (33, 34), (39 - draw, 38), (44 - draw, 35),
         (46 - draw, 37), (40 - draw, 42), (33, 39)], SHADOW)
    a.r(43 - draw, 35, 3, 2, CREAM)
    a.p([(49, 17), (53, 20), (56, 28), (56, 43), (53, 51),
         (49, 54), (50, 49), (52, 43), (53, 35), (52, 27), (50, 21)], CREAM)
    a.r(54, 29, 1, 13, GOLD)
    # The pulled string is itself stepped to match the pixel grid.
    a.p([(50, 19), (49, 19), (46 - draw, 36), (49, 52),
         (50, 52), (47 - draw, 36)], BRASS, None)
    a.r(44 - draw, 35, 15, 1, GOLD)
    a.p([(58, 33), (61, 35), (58, 37)], PAPER, None)
    a.end()


def bat(a, animation, frame):
    # Three hand-authored wing contours: upstroke, spread and folded downstroke.
    wing_phase = (frame % 4) if animation != "idle" else [0, 1, 2, 1][frame]
    if animation == "warning":
        wing_phase = 3
    if animation == "cast":
        wing_phase = [3, 0, 2, 1][frame]
    if animation == "hit":
        wing_phase = 2
    wings = [
        [(29, 31), (21, 20), (18, 8), (13, 15), (6, 11), (9, 26), (4, 32), (16, 30), (20, 39)],
        [(29, 30), (18, 23), (7, 20), (4, 30), (7, 36), (15, 32), (20, 40)],
        [(29, 30), (20, 28), (11, 34), (8, 46), (17, 43), (20, 49), (25, 39)],
        [(29, 30), (25, 23), (21, 18), (22, 34), (18, 41), (26, 43)],
    ]
    a.group(0, [0, -1, 0, 1][frame % 4])
    for flip in (False, True):
        if flip:
            a.parts.append('<g transform="translate(64 0) scale(-1 1)">')
        a.p(wings[wing_phase], PURPLE)
        root, tip = (26, 31), wings[wing_phase][2]
        a.p([root, (tip[0] + 2, tip[1] + 3), (tip[0] + 3, tip[1] + 8), (23, 36)], "583f66", None)
        a.r(tip[0], tip[1], 2, 3, CREAM)
        if flip:
            a.end()
    a.p([(26, 28), (26, 18), (30, 22), (34, 22), (38, 17),
         (38, 29), (40, 35), (35, 42), (32, 49), (29, 42), (24, 35)], SHADOW)
    a.p([(28, 27), (35, 26), (37, 31), (34, 37), (32, 39), (28, 34)], CREAM, None)
    a.r(27, 29, 3, 2, RED)
    a.r(34, 29, 3, 2, RED)
    a.r(31, 33, 2, 3, INK)
    a.r(29, 36, 1, 2, PAPER)
    a.r(35, 36, 1, 2, PAPER)
    a.r(31, 42, 2, 3, MID)
    a.end()


def sentinel(a, animation, frame):
    step, breath, _cloth = movement(animation, frame)
    raise_shield = [0, 2, 4, 5][frame] if animation == "warning" else 4 if animation == "rush" else 0
    for x, shift in [(26, -step), (35, step)]:
        a.p([(x, 43), (x + 6, 43), (x + shift + 5, 53),
             (x + shift + 8, 57), (x + shift - 1, 57)], SHADOW)
        a.r(x + shift, 53, 6, 2, STONE)
        a.r(x + shift + 1, 54, 4, 1, CREAM)
    a.group(0, breath)
    # Halberd, broad pauldrons and a closed helmet contrast with the archer.
    a.r(13, 14, 2, 40, BRASS)
    a.r(13, 16, 1, 36, GOLD)
    a.p([(13, 6), (16, 13), (19, 17), (15, 20), (8, 21), (9, 15), (12, 16)], CREAM)
    a.p([(25, 27), (19, 28), (18, 35), (23, 38), (26, 35),
         (28, 44), (40, 44), (44, 34), (41, 27)], STONE)
    a.p([(27, 30), (38, 30), (39, 40), (33, 44), (28, 40)], SHADOW)
    a.r(28, 31, 10, 2, CREAM)
    a.r(31, 35, 3, 6, BRASS)
    a.r(32, 35, 1, 5, GOLD)
    a.p([(26, 18), (29, 14), (37, 14), (41, 19), (39, 27),
         (33, 30), (27, 26)], STONE)
    a.p([(29, 16), (36, 16), (38, 19), (36, 20), (29, 20)], CREAM, None)
    a.r(27, 21, 13, 3, INK)
    a.r(29, 22, 3, 1, RED)
    a.r(35, 22, 3, 1, RED)
    a.r(33, 17, 1, 11, BRASS)
    a.p([(20, 32), (17, 35), (14, 35), (14, 39), (19, 39), (24, 35)], STONE)
    a.r(13, 34, 3, 3, CREAM)
    # Shield is a moving foreground prop with an inset thorn device.
    a.group(raise_shield // 2, -raise_shield)
    a.p([(41, 28), (52, 26), (58, 31), (57, 46), (49, 55), (40, 49), (38, 35)], BRASS)
    a.p([(42, 31), (51, 29), (55, 32), (54, 45), (49, 51), (43, 47), (41, 36)], "485a59", None)
    a.r(47, 33, 2, 14, GOLD)
    a.r(44, 36, 8, 2, GOLD)
    a.r(44, 34, 2, 4, GOLD)
    a.r(51, 40, 2, 4, GOLD)
    a.r(42, 31, 2, 2, CREAM)
    a.r(53, 33, 2, 2, CREAM)
    a.end()
    a.end()


def flame(a, x, y, phase=0, color=BLUE, small=False):
    a.group(x, y)
    if small:
        a.p([(0, 9), (1, 5), (3 + phase % 2, 0), (4, 5),
             (7, 8), (6, 12), (2, 13)], color)
        a.r(3, 8, 2, 4, PAPER)
    else:
        lean = [-2, 0, 2, 0][phase % 4]
        a.p([(0, 18), (2, 10), (7, 8), (8 + lean, 0), (12, 8),
             (15, 5), (17, 14), (20, 17), (18, 27), (11, 32), (3, 28)], color)
        a.p([(6, 19), (10, 11), (11, 19), (14, 17), (15, 25),
             (11, 28), (7, 26)], PAPER, None)
    a.end()


def wisp(a, animation, frame):
    _step, breath, cloth = movement(animation, frame)
    charge = animation in ("warning", "cast")
    phase = frame + (1 if charge else 0)
    a.group(0, breath)
    # Tall licking flame, empty robe, and a hanging cage lantern are unique props.
    flame(a, 21, (3 if charge else 6) + [0, -2, 1, -1][frame % 4], phase, CYAN)
    a.p([(23, 28), (36, 28), (39, 37), (43 + cloth, 46),
         (36, 43), (38, 51), (31, 47), (28, 55), (25, 48),
         (19 - cloth, 51), (22, 42), (17, 44), (20, 35)], "537b89")
    a.p([(25, 31), (30, 33), (29, 43), (26, 49), (25, 42), (22, 44)], "82b7c0", None)
    a.p([(25, 23), (33, 22), (36, 27), (33, 32), (26, 31), (23, 27)], DEEP, None)
    a.eye(25, 26, PAPER)
    a.eye(32, 26, PAPER)
    a.p([(36, 33), (41, 35 - (2 if charge else 0)), (47, 33 - (3 if charge else 0)),
         (48, 36), (43, 40), (37, 38)], "82b7c0")
    lx, ly = 47 + cloth, 39 - (4 if charge else 0)
    a.r(lx, ly - 4, 1, 8, GOLD)
    a.p([(lx - 3, ly + 2), (lx + 3, ly + 2), (lx + 5, ly + 7),
         (lx + 3, ly + 15), (lx - 3, ly + 15), (lx - 5, ly + 7)], BRASS)
    a.r(lx - 2, ly + 5, 5, 7, DEEP)
    a.r(lx - 1, ly + 6, 3, 5, BLUE)
    a.r(lx, ly + 7, 1, 3, PAPER)
    a.r(lx - 3, ly + 12, 7, 1, GOLD)
    if charge:
        a.star(lx + 4, ly, BLUE, 2)
    a.end()


def flower(a, x, y):
    a.r(x - 2, y - 1, 5, 3, GOLD)
    a.r(x - 1, y - 2, 3, 5, GOLD)
    a.r(x, y, 1, 1, PAPER)


def thorn(a, animation, frame):
    step, breath, branches = movement(animation, frame)
    lift = [0, 3, 6, 8][frame] if animation == "warning" else [8, 6, 2, 0][frame] if animation == "cast" else 0
    reach = 6 if animation == "rush" else 0
    for x, shift in [(34, -step), (53, step)]:
        a.p([(x, 65), (x + 11, 65), (x + 12 + shift, 80),
             (x + 19 + shift, 87), (x + 9 + shift, 88), (x + 4 + shift, 85),
             (x - 4 + shift, 89), (x - 8 + shift, 85), (x - 2, 75)], "59675e")
        a.p([(x + 2, 70), (x + 6, 70), (x + 8 + shift, 82),
             (x + 13 + shift, 86), (x + 7 + shift, 84)], CREAM, None)
    a.group(0, breath)
    # Layered wooden shoulders, exposed cyan seams and vines define the giant.
    a.p([(27, 35), (37, 29), (57, 29), (70, 37), (68, 57),
         (60, 70), (46, 74), (31, 67), (24, 54)], "59675e")
    a.p([(34, 38), (45, 42), (60, 36), (64, 48), (57, 59),
         (47, 65), (36, 58), (30, 46)], SHADOW)
    a.p([(35, 36), (40, 42), (36, 47), (41, 54), (38, 60),
         (32, 52), (29, 41)], CREAM, None)
    a.p([(56, 37), (61, 38), (60, 45), (55, 51), (57, 57), (51, 64),
         (49, 59), (52, 52), (50, 45)], STONE, None)
    a.r(44, 47, 2, 13, CYAN)
    a.r(42, 49, 6, 2, BLUE)
    # Both branch arms articulate at the elbow; raised fists are a warning.
    for side in (-1, 1):
        ox = -branches if side < 0 else branches + reach
        a.group(ox, -lift if side > 0 else -lift // 2)
        if side > 0:
            a.parts.append('<g transform="translate(96 0) scale(-1 1)">')
        a.p([(27, 36), (19, 36), (12, 45), (10, 56), (5, 66),
             (9, 76), (19, 77), (27, 69), (25, 59), (30, 48)], "59675e")
        a.p([(20, 40), (16, 47), (15, 57), (11, 63), (12, 71),
             (17, 73), (20, 65), (19, 57), (24, 48)], CREAM, None)
        a.p([(9, 55), (4, 50), (8, 51), (10, 46), (12, 55)], GOLD)
        a.p([(23, 62), (29, 57), (26, 65), (29, 69), (22, 68)], GOLD)
        a.r(14, 60, 9, 2, CYAN)
        flower(a, 18, 46)
        if side > 0:
            a.end()
        a.end()
    # Ivory tree mask and the moving antler crown.
    antler(a, 29 - branches, 4, -1)
    antler(a, 53 + branches, 2)
    antler(a, 40, 2, -1, STONE)
    a.p([(37, 25), (47, 20), (59, 25), (61, 34), (56, 43),
         (48, 48), (40, 42), (35, 32)], CREAM)
    a.p([(40, 26), (45, 23), (47, 33), (44, 39), (39, 34)], PAPER, None)
    a.p([(51, 25), (57, 27), (58, 33), (51, 40), (48, 44), (49, 33)], STONE, None)
    a.p([(39, 32), (44, 34), (44, 37), (40, 36)], INK, None)
    a.p([(51, 34), (57, 30), (55, 36), (51, 38)], INK, None)
    a.r(41, 34, 3, 1, BLUE)
    a.r(52, 34, 3, 1, BLUE)
    a.r(47, 40, 2, 5, INK)
    flower(a, 33, 30)
    flower(a, 64, 33)
    flower(a, 49, 64)
    a.end()


def shard(a, x, y, w=7, h=15, light=False):
    a.p([(x, y), (x + w, y + 3), (x + w - 1, y + h - 3),
         (x + 2, y + h), (x - 2, y + h // 2)], BLUE if light else "697eaf")
    a.r(x + 1, y + 4, 1, h - 6, PAPER if light else LILAC)


def mirror(a, animation, frame):
    _step, breath, orbit = movement(animation, frame)
    spread = [0, -2, -4, -5][frame] if animation == "warning" else [0, 5, 8, 2][frame] if animation == "cast" else 0
    a.group(0, breath)
    cloak(a, 24, 52, 48, 85, orbit, "493c64")
    a.p([(37, 67), (43, 65), (42, 81), (38, 87), (35, 81)], LILAC, None)
    a.p([(57, 65), (63, 65), (65, 82), (58, 87)], MID, None)
    # Independent shards do not share the mirror body's translation/rotation.
    for i, (x, y, w, h) in enumerate([(14, 22, 7, 19), (12, 49, 8, 12),
                                   (74, 19, 8, 18), (76, 49, 6, 17),
                                   (20, 72, 7, 11), (72, 75, 7, 10)]):
        direction = -1 if x < 48 else 1
        shard(a, x + direction * (orbit + spread), y + ((frame + i) % 3 - 1), w, h, i % 2 == 0)
    a.p([(33, 15), (43, 11), (57, 12), (68, 20), (73, 36),
         (70, 58), (59, 72), (43, 74), (29, 63), (23, 44), (26, 26)], BRASS)
    a.p([(34, 19), (44, 15), (56, 16), (64, 23), (68, 37),
         (65, 55), (57, 67), (43, 69), (33, 60), (28, 44), (30, 29)], GOLD, None)
    a.p([(36, 22), (44, 19), (55, 20), (61, 26), (64, 38),
         (61, 53), (55, 63), (44, 65), (36, 57), (32, 43), (33, 30)], "3f4a78")
    a.p([(36, 25), (43, 21), (53, 21), (43, 37), (34, 49),
         (33, 41)], "697eaf", None)
    a.p([(58, 30), (62, 39), (59, 52), (54, 59), (45, 61)], "697eaf", None)
    # A phantom face appears in the mirror; the eyes close on the blink frame.
    a.p([(42, 32), (52, 29), (57, 36), (56, 46), (49, 53),
         (42, 47), (39, 39)], "98b6cc", None)
    a.r(42, 37, 4, 1 if frame == 3 and animation == "idle" else 2, INK)
    a.r(51, 36, 4, 2, INK)
    a.r(43, 37, 2, 1, BLUE)
    a.r(52, 36, 2, 1, BLUE)
    a.r(48, 43, 1, 5, SHADOW)
    a.r(46, 49, 6, 1, PURPLE)
    a.r(37, 27, 2, 9, PAPER)
    a.r(35, 33, 2, 4, PAPER)
    a.p([(40, 12), (38, 5), (45, 9), (49, 3), (53, 10),
         (60, 7), (57, 15)], GOLD)
    a.r(47, 10, 4, 4, LILAC)
    a.star(49, 70, GOLD, 3)
    a.end()


def bell(a, animation, frame):
    _step, breath, cloth = movement(animation, frame)
    ring = [0, -6, 0, 6][frame % 4]
    lift = [0, 2, 4, 6][frame] if animation == "warning" else [6, 3, 0, 0][frame] if animation == "cast" else 0
    if animation == "warning":
        ring = 0
    a.group(0, breath)
    cloak(a, 19, 38, 58, 85, cloth, DEEP)
    a.p([(29, 49), (36, 50), (30, 74), (24, 82), (24, 70)], SHADOW, None)
    a.p([(65, 47), (70, 50), (77, 78), (67, 82), (67, 66)], SHADOW, None)
    # Two chains and curled hands hang outside the bell shell.
    for side in (-1, 1):
        if side > 0:
            a.parts.append('<g transform="translate(96 0) scale(-1 1)">')
        for i in range(5):
            a.p([(22 - i, 25 + i * 5), (25 - i, 26 + i * 5),
                 (25 - i, 30 + i * 5), (22 - i, 31 + i * 5), (20 - i, 29 + i * 5)], BRASS)
            a.r(22 - i, 26 + i * 5, 1, 3, GOLD)
        a.p([(15, 47), (20, 46), (23, 51), (21, 59), (16, 65),
             (11, 62), (10, 56)], SHADOW)
        a.r(13, 53, 2, 8, MID)
        a.r(17, 52, 2, 7, STONE)
        if side > 0:
            a.end()
    a.group(0, -lift)
    a.p([(39, 18), (39, 11), (43, 7), (52, 7), (57, 12),
         (56, 19), (51, 22), (44, 22)], BRASS)
    a.p([(44, 11), (50, 11), (53, 14), (51, 17), (44, 17)], INK, None)
    a.p([(36, 20), (43, 16), (54, 17), (62, 22), (66, 34),
         (69, 50), (77, 60), (75, 67), (63, 72), (37, 72), (23, 66),
         (22, 60), (30, 50), (33, 34)], BRASS)
    a.p([(39, 22), (44, 20), (51, 21), (45, 30), (42, 48),
         (35, 59), (28, 61), (35, 48), (38, 32)], GOLD, None)
    a.p([(54, 23), (59, 25), (63, 37), (64, 49), (70, 58),
         (64, 61), (57, 48)], "665443", None)
    a.p([(26, 60), (39, 56), (60, 57), (73, 62), (69, 67),
         (59, 70), (38, 69), (27, 65)], INK)
    a.p([(33, 61), (41, 59), (58, 60), (65, 63), (58, 66), (40, 65)], PURPLE, None)
    # The clapper sweeps on its own axis and visibly exits the dark bell mouth.
    a.p([(47, 59), (51, 59), (51 + ring, 72), (55 + ring, 75),
         (53 + ring, 81), (46 + ring, 81), (43 + ring, 76), (47 + ring, 72)], BRASS)
    a.r(48 + ring, 74, 3, 5, GOLD)
    a.r(49 + ring, 75, 1, 3, PAPER)
    a.r(37, 32, 4, 3, INK)
    a.r(57, 32, 4, 3, INK)
    a.r(38, 33, 3, 1, BLUE)
    a.r(57, 33, 3, 1, BLUE)
    a.r(46, 30, 3, 16, GOLD)
    a.r(43, 36, 9, 2, GOLD)
    a.r(30, 53, 6, 2, GOLD)
    a.r(63, 52, 4, 2, GOLD)
    a.end()
    a.end()


DRAW = {"witch": witch, "hound": hound, "charger": charger, "archer": archer,
        "bat": bat, "sentinel": sentinel, "wisp": wisp, "boss_thorn": thorn,
        "boss_mirror": mirror, "boss_bell": bell}


def svg_frame(kind, animation, frame, index, cell):
    a = Art()
    # Clip and death fragments are authored in vector space, never rasterized here.
    if animation == "death" and frame == 4:
        return ""
    if animation in ("death", "arrival"):
        clip_id = f"{kind}-{index}"
        if animation == "arrival":
            width = [cell // 3, cell // 2, cell * 3 // 4, cell][frame]
            rects = f'<rect x="{(cell - width) // 2}" y="0" width="{width}" height="{cell}"/>'
        elif frame == 0:
            rects = f'<rect width="{cell}" height="{cell}"/>'
        else:
            # Gaps widen between larger remaining pieces in successive key poses.
            rects = "".join(f'<rect x="{x}" y="{y}" width="{max(1, 8 - frame * 2)}" height="{max(1, 8 - frame * 2)}"/>'
                            for y in range(0, cell, 8) for x in range((y // 8 % 2) * 2, cell, 8)
                            if (x // 8 + y // 8 + frame) % (frame + 1) != 0)
        a.parts.append(f'<defs><clipPath id="{clip_id}">{rects}</clipPath></defs>')
        a.group(0, 2 * frame if animation == "death" else 0, f'clip-path="url(#{clip_id})"')
    DRAW[kind](a, "hit" if animation == "death" else "idle" if animation == "arrival" else animation,
               min(frame, 1) if animation == "death" else frame)
    if animation in ("death", "arrival"):
        a.end()
        if animation == "death" and frame > 0:
            for i in range(8 - frame):
                x = cell // 2 + ((i * 13 + frame * 7) % 29) - 14
                y = cell // 2 + ((i * 19 + frame * 5) % 31) - 18 - frame * 3
                a.r(x, y, 2 if i % 2 else 1, 2, GOLD if i % 3 == 0 else BLUE if kind == "wisp" else MID)
    return a.text()


def main():
    for kind in DRAW:
        cell = 96 if kind.startswith("boss_") else 64
        pieces = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{cell * 8}" height="{cell * 5}" viewBox="0 0 {cell * 8} {cell * 5}" shape-rendering="crispEdges">',
                  '<title>Echo Witch original combat pixel sprite atlas</title>',
                  '<desc>Original code-authored grid-aligned vector artwork for Echo Witch. 36 frames; 8 columns. No source image used.</desc>']
        pieces.append(f'<defs><clipPath id="cell"><rect width="{cell}" height="{cell}"/></clipPath></defs>')
        index = 0
        for animation, count in ANIMATIONS:
            for frame in range(count):
                pieces.append(f'<g id="{animation}-{frame}" transform="translate({index % 8 * cell} {index // 8 * cell})" clip-path="url(#cell)">')
                pieces.append(svg_frame(kind, animation, frame, index, cell))
                pieces.append('</g>')
                index += 1
        pieces.append('</svg>\n')
        (OUT / f"pixel-actors-{kind.replace('_', '-')}.svg").write_text("".join(pieces))
    print(f"Authored {len(DRAW)} original SVG atlases, 36 frames each; no raster processing.")


if __name__ == "__main__":
    main()
