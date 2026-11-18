"""An's fabric sun visor, with the brim sewn through the headband."""
from math import cos, exp, pi, sin

from mathutils import Vector

from forms import CAST, hair_profile


def build_visor(g):
    an = CAST[3]

    def band(a, z_offset, allowance=0):
        front = max(0, cos(a))
        z = 287 + 15 * sin(a) + z_offset
        v = max(0, min(1, (an['floor'] - z / an['k'] - 50) / 166))
        p = Vector(hair_profile(an, a, v))
        # The forelock stands farther out than the skull profile. Keep the
        # cloth in front of it while the return below reaches into the hair.
        clearance = 4.7 * exp(-((a / 1.25)**4))
        p += Vector((sin(a), -cos(a), 0)) * (9 + 3.5 * front + clearance + allowance)
        p.z = z
        return p

    # The front holds its embroidered mark. The lower section stays broad
    # at the temples, and narrows to a strap at the back.
    sections = ((0, -.65), (.08, .4), (.57, .9), (.93, .35), (1, -.61))
    angles = [-pi + k * 2 * pi / 72 for k in range(72)]

    def band_row(height, allowance):
        return [band(a, height * (19 + 21 * max(0, cos(a))**.83), allowance) for a in angles]

    wrap = [band_row(height, allowance) for height, allowance in sections]
    wrap.extend(band_row(height, -15.7) for height, _ in reversed(sections))
    wrap.append(wrap[0])
    g.grid(wrap, 'Head', 12, cap=False)

    # Cross sections contain the top, both short edges and the underside.
    # Slightly bury the root in the band. The lip closes smoothly without an
    # exposed rim, including in the low camera when An lifts her chin.
    brim = []
    bill_angles = [-1.43 + k * 2.86 / 48 for k in range(49)]
    for t, thickness in ((0, 4.1), (.14, 4.4), (.31, 4.65), (.55, 4.6),
                         (.74, 4.3), (.88, 3.9), (.97, 2.6), (1, .92)):
        top, bottom = [], []
        for a in bill_angles:
            front = cos(a)
            p = band(a, 2.9, -1.65)
            p += Vector((sin(a) * (4.5 + 4.2 * front) * t,
                         -(1.6 + 24.7 * front**.80) * t,
                         2.8 * sin(pi * t) - (1.1 + 2.5 * (1 - front)) * t))
            depth = thickness * (.45 + .55 * front)
            top.append(p + Vector((0, 0, depth * .55)))
            bottom.append(p - Vector((0, 0, depth * .45)))
        brim.append(top + bottom[::-1])
    g.grid(brim, 'Head', 12, reverse=True)

    def mark(a, z, allowance):
        return band(a, z, allowance)

    g.polygon([mark(-.153, 12, 1.9), mark(.159, 12, 1.9), mark(.01, 31, 1.95)], 'Head', 9)
    g.polygon([mark(-.025, 15.8, 2.3), mark(.106, 15.8, 2.3), mark(-.006, 26.4, 2.3)], 'Head', 12)
