"""Tailored athletic clothing and contact surfaces for the shared race skeleton."""
from math import cos, pi, sin

from mathutils import Vector

from forms import PALETTE


TAU = 2 * pi


def joint_weights(g, first, columns, weights, following):
    for row, weight in enumerate(weights):
        if weight:
            for vertex in range(first + row * columns, first + (row + 1) * columns):
                g.blends.append((vertex, following, weight))


def swatch_quad(swatch):
    if isinstance(swatch, str):
        swatch = PALETTE.index(swatch)
    return [((32 * swatch + 16) / 1024, 1 - 544 / 1024)] * 4


def cloth(g, rows, bone, color, reverse, paint, cap=True):
    """Use the palette row of the common atlas on a connected shell."""
    g.grid(rows, bone, color, reverse=reverse, cap=cap,
           face_tex=lambda row, column: swatch_quad(paint(row, column)))


def sleeve(g, i, side, sign):
    upper, forearm = 'UpperArm.' + side, 'Forearm.' + side
    # The root lies inside the chest. Its weights keep the raglan shoulder
    # attached as the elbow swings behind the bib or the hand reaches up.
    stations = [(24, 1, 190, 8, 12), (30, 1, 186, 12.8, 14),
                (37, 0, 181, 15.4, 16.6), (44, -.5, 174, 15.9, 15.8),
                (50, .3, 166, 15.2, 15), (55, .5, 159, 14.1, 14.1),
                (60, 0, 153, 13.9, 14), (64, -1, 148, 14.2, 14.3),
                (68, -2, 143, 13.9, 13.9), (71, -3, 138.5, 13, 13.3),
                (73, -4, 135.5, 12.5, 12.7), (75, -4.6, 132.4, 11.7, 12),
                (76, -5, 130.1, 10.1, 10.7)]
    cols = 36

    def surface(j, angle, extra=0):
        x, y, z, radius, depth = stations[j]
        fold = .62 * cos(2 * angle + .53 * j) + .42 * cos(3 * angle - .6 * j)
        radius += extra + (fold if 3 <= j <= 9 else .19 * fold)
        return (sign * (x + .77 * radius * sin(angle)), y - (depth + extra) * cos(angle),
                z + .64 * radius * sin(angle))

    if i == 3:
        # An's short sleeve gives way to a bare forearm under the white binding.
        for j in range(7, len(stations)):
            x, y, z, r, d = stations[j]
            stations[j] = (x, y, z, (r - 2.4) if j < 11 else (r - 2.0), d - 2.2)

    def paint(row, col):
        if i == 3 and row >= 6:
            return 9 if row == 6 else 'skin'
        if i != 3 and row == 10:
            return 9
        if i in (1, 2, 5) and 1 <= row <= 4 and col in ((11, 13) if i == 2 else (11,)):
            return 9
        return 'sleeve'

    rows = [[surface(j, k * TAU / cols) for k in range(cols)] for j in range(len(stations))]
    first = len(g.verts)
    cloth(g, rows, upper, 'sleeve', sign == 1, paint)
    joint_weights(g, first, cols, [1, .55, .10], 'Chest')
    joint_weights(g, first, cols, [0, 0, 0, 0, .04, .22, .50, .78, .94, 1, 1, 1, 1], forearm)

    # Sew the nautical crest to the curved shoulder. Its white border
    # follows the same deformation as the cloth below it.
    cols = 11
    patch = []
    first = len(g.verts)
    for r in range(9):
        progress = r / 8
        j = 2 + 1.94 * progress
        lo = int(j)
        row = []
        for k in range(cols):
            u = k / (cols - 1)
            span = .54 * (1 - .13 * abs(2 * progress - 1))
            angle = 1.18 + (2 * u - 1) * span
            row.append(Vector(surface(lo, angle, .95)).lerp(surface(lo + 1, angle, .95), j - lo))
        patch.append(row)
    def crest_ink(row, col):
        if row in (0, 7) or col in (0, cols - 2):
            return 9
        u, v = (col + .5) / (cols - 1), (row + .5) / 8
        if abs(v - .5) > .86 * abs(u - .5):
            return 10 if i in (0, 1, 5) else 'jacket'
        return 'shoe'
    g.grid(patch, upper, 9, wrapped=False, reverse=sign == 1, cap=False,
           face_tex=lambda row, col: swatch_quad(crest_ink(row, col)))
    joint_weights(g, first, cols, [max(0, .10 - .194 * r / 8) for r in range(9)], 'Chest')


def hand(g, side, sign):
    bone = 'Hand.' + side

    def p(x, y, z):
        return (sign * x, y, z)

    # The first small ring sits inside the cuff on the wrist pivot. The base
    # of each finger lies within the palm before its tip opens into a fan.
    g.loft([(111.3, 7.2, 6.3, sign * 85.8, -7.3),
            (113.7, 10.8, 8.5, sign * 84.3, -7.0),
            (117, 11.1, 9, sign * 82.2, -6.7),
            (124, 9.4, 8.4, sign * 79.2, -5.8),
            (130, 7.9, 7.0, sign * 76.5, -4.9),
            (135, 5.9, 5.9, sign * 75.3, -4.6)], bone, 'skin', 24)
    for dx, dy, length in ((-6.6, -3.1, 11), (-2.4, -1, 12), (2.3, 1.2, 11.2), (6.7, 3.2, 9.1)):
        x, y = 85 + dx, -7 + dy
        g.tube([p(x, y, 114.9), p(x + 2.5 + .18 * dx, y - 1.5, 110.5),
                p(x + 4.1 + .24 * dx, y - 3.0, 115 - length + 1.6),
                p(x + 4.0 + .29 * dx, y - 4.25, 115 - length)],
               [3.25, 3.05, 2.65, .49], bone, 'skin', n=10, steps=2)
    g.tube([p(75.5, -9, 122.7), p(72.6, -11.3, 119.4),
            p(70.7, -14.1, 115), p(70.8, -15.7, 111.5)],
           [4.5, 4.2, 3.3, .6], bone, 'skin', n=10, steps=3)


def legs(g, i, side, sign):
    thigh, shin, foot = ('Thigh.' + side, 'Shin.' + side, 'Foot.' + side)
    cols = 36
    long = i in (2, 5)
    # The tape turns into the skin at the cuff. A second full thigh under the
    # shorts intersects the back of the shorts as a running knee drives up.
    # One shell keeps the skin, binding and side stripe joined in every pose.
    cuts = [(23, 1, 128, 18, 19), (23, .3, 121, 20.7, 22),
            (24, 0, 113, 21.6, 21.6), (24.7, -.1, 105, 22.1, 20.3),
            (25, -.25, 102, 22.2, 19.5), (25.3, -.4, 99, 21.3, 18.9),
            (25.4, -.45, 98.7, 18.7, 16.6), (25.5, -.5, 96.7, 18.3, 16.3)]
    calf = [(27, -.5, 88, 17.0, 16.2), (27.8, -.3, 82, 16.5, 15.7),
            (28, -1, 77, 16.0, 15.5), (28.5, -.8, 72, 16.2, 16),
            (28.8, -.4, 70, 16.9, 16.8), (29.4, .6, 66.5, 16.9, 17),
            (30, 1.1, 60.5, 16.4, 16.6), (31.1, 1.4, 50, 14.4, 14.9),
            (32, .2, 40, 13.4, 13.4), (32, 0, 34, 12.9, 12.7)]
    stations = (cuts[:4] if long else cuts) + calf
    if long:
        extra = 3.3 if i == 5 else 2.0
        stations = [(x, y, z, w + extra, d + extra) for x, y, z, w, d in stations]
    # The outer hems lift slightly around the lateral seam.
    def at(j, angle):
        x, y, z, width, depth = stations[j]
        ripple = (.55 * sin(3 * angle + .6 * j) + .48 * sin(2 * angle - .89 * j)) if long else 0
        rise = 0 if long or j > 7 else (2.6 * max(0, sin(angle))**2 - .8 * cos(angle + .6))
        return (sign * (x + (width + ripple) * sin(angle)), y - (depth + ripple) * cos(angle), z + rise)

    def paint(row, col):
        if long:
            stripes = (7, 9) if i == 2 else (8,)
            return 9 if col in stripes else 'pants'
        if row <= 3:
            return 9 if col in (7, 8) else 'pants'
        if row <= 5 or row == 12:
            return 9
        if row == 13:
            return 'sock'
        return 'skin' if row < 12 else 9

    rows = [[at(j, k * TAU / cols) for k in range(cols)] for j in range(len(stations))]
    first = len(g.verts)
    cloth(g, rows, thigh, 'pants', sign == 1, paint)
    # Both sides of a material edge use the same knee weights, so the red
    # band cannot be left behind by the calf when the knee bends.
    weights = [0, 0, 0, 0, .08, .23, .50, .76, .88, .97, 1, 1, 1, 1]
    if not long:
        weights[4:4] = [.015, .025, .026, .038]
    joint_weights(g, first, cols, weights, shin)


def sneaker(g, side, sign):
    foot = 'Foot.' + side
    cx = sign * 33
    cols = 48
    # The toe remains broad out to its guard. The higher heel cup straightens
    # towards the ankle, and the reference's thick foxing rises at both ends.
    levels = [(1.25, 28, 37.0, -8.2), (4.2, 30.4, 40.4, -8.1),
              (8.6, 32, 42.7, -7.9), (13.6, 32.1, 42.5, -7.3),
              (19, 31.7, 41.8, -7.2), (22.4, 31.0, 39.7, -6.6),
              (24.7, 29.8, 38, -5.5), (29.3, 28, 34.2, -3.7),
              (34.9, 25.9, 29.3, -1.5), (39.8, 23.2, 24.3, 1.7),
              (42.7, 21.1, 20.1, 4.6), (44.8, 17.5, 16.7, 5)]

    def at(j, angle, lift=0):
        z, rx, ry, offset = levels[j]
        c = cos(angle)
        toe, heel = max(0, c), max(0, -c)
        x = cx + sign * ((rx + lift) * sin(angle) * (1 - .11 * heel + .058 * toe) + 2.6 * toe)
        y = offset - (ry + lift) * c - 6.5 * toe * max(0, (46 - z) / 46)
        arch = 4.5 * max(0, 1 - abs(y - 7.5) / 14) * max(0, (15 - z) / 15)
        toe_curve = (0, 5.3, 3.8, 5.0, 1.7)[j] if j < 5 else 0
        heel_curve = (0, 2.6, 2.6, 1.9, 1.7)[j] if j < 5 else 1.4
        collar = (-2.9 * toe + 1.5 * heel) if j > 8 else 0
        return Vector((x, y, z + arch + 2.0 * toe**4 + toe_curve * toe**9 + heel_curve * heel**9 + collar))

    def paint(row, _col):
        return 14 if row == 0 else (9 if row <= 2 else 'shoe')

    rows = [[at(j, k * TAU / cols) for k in range(cols)] for j in range(len(levels))]
    cloth(g, rows, foot, 'shoe', sign < 0, paint, cap=False)
    lower, upper = rows[0], rows[-1]
    g.polygon(lower[::-1] if sign > 0 else lower, foot, 14)
    g.polygon(upper if sign > 0 else upper[::-1], foot, 'shoe')

    # The rounded leather insert follows the upper from the top of the
    # foxing. The two smaller inserts wrap into the instep on the sides.
    for center, span, height in ((pi, .62, 1.77), (-1.83, .34, 1.05), (1.83, .34, 1.05)):
        rows = []
        for f in (0, .34, .67, 1):
            points = []
            for k in range(17):
                u = k / 8 - 1
                angle = center + span * u
                j = 2.98 + f * height * max(.014, 1 - u * u)**.63
                lo = int(j)
                points.append(at(lo, angle, .50).lerp(at(lo + 1, angle, .50), j - lo))
            rows.append(points)
        g.grid(rows, foot, 9, wrapped=False, reverse=sign < 0, cap=False)
    # The padded tongue sits inside the opening and the two rounded straps
    # wrap the toe. The opening stays low in front of the ankle.
    g.oval((cx + sign, -15.6, 35.8), (14.2, 14.1, 10), foot, 'shoe', 20, 10)
    for level, span in ((6.94, .95), (8.34, .89)):
        points = []
        for k in range(13):
            u = -1 + k / 6
            a = span * u
            j = level - .82 * u * u
            lo = int(j)
            pt = at(lo, a, .9).lerp(at(lo + 1, a, .9), j - lo)
            pt.z += 1.2 * (1 - u * u)
            points.append(pt)
        radii = [1.6 + 2.65 * (1 - (k / 6 - 1)**2) for k in range(13)]
        g.tube(points, radii, foot, 9, flat=.85, n=10, steps=1, plane=(0, -.7, .72))
    # The back of the collar curls inward round the sock and ends in a
    # padded horizontal heel tab.
    points = [at(9, pi - 1.04 + k * 2.08 / 16, .4) for k in range(17)]
    g.tube(points, [1.8 + 1.1 * sin(pi * k / 16) for k in range(17)], foot, 'shoe', n=10, steps=1)
    g.oval((cx, 25.2, 36.6), (11, 5.2, 4.7), foot, 'shoe', 20, 8)
    for y, width in ((-33, 18), (-19, 22), (-5, 22), (12, 17), (22, 13)):
        g.oval((cx, y, .95), (width, 4.6, .95), foot, 16, 12, 4)
