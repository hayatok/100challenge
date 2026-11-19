"""Bake the opening market's produce stand, side door, shutter and boarding point."""
import math
import random
import sys
import wave
from array import array
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from landmarks import Building, OUT, arcade

INK = "344541"
CREAM = "f0d7a1"
VERMILION = "be572e"
RUST = "824e34"
TRIM = "cb9a4c"
TEAL = "48746b"
STEEL = "70817e"


def canopy():
    g = Building(0)
    for x in (-2.1, 2.1):
        for z in (-1.48, 1.48):
            g.box(x, .067, z, .25, .13, .25, INK)
            g.box(x, 1.23, z, .11, 2.33, .12, TEAL)
            g.beam((x, 2.4, z), (x * .76, 2.53, z * .75), .052, .061, STEEL)
        g.beam((x, 2.43, -1.48), (x, 2.51, 1.48), .075, .084, STEEL)
    for x in (-2.1, 0, 2.1):
        g.beam((x, 2.71, -1.53), (x, 2.40, 1.61), .070, .069, STEEL)
    # Aging terracotta and cream panels share seams and a deeply cut scalloped edge.
    for j in range(13):
        x0 = -2.59 + j * .398
        x1 = x0 + .398
        shade = ("c55f36", "d8c393", "b9532f", "ead2a0")[j % 4]

        def point(x, t):
            scallop = math.sin((x - x0) * math.pi / (x1 - x0))
            return (x, 2.79 - .39 * t - .105 * math.sin(math.pi * t) - .028 * scallop,
                    -1.63 + 3.58 * t)

        for k in range(5):
            u, v = k / 5, (k + 1) / 5
            g.face([point(x0, u), point(x1, u), point(x1, v), point(x0, v)], shade, 4)
        for k in range(4):
            left, right = x0 + .398 * k / 4, x0 + .398 * (k + 1) / 4
            a, b = point(left, 1), point(right, 1)
            hem_a = (left, a[1] - .15 - .074 * math.sin(k * math.pi / 4), 1.97)
            hem_b = (right, b[1] - .15 - .074 * math.sin((k + 1) * math.pi / 4), 1.97)
            g.face([a, b, hem_b, hem_a], shade, 4)
    for x in (-2.1, 2.1):
        g.beam((x, 2.42, 1.48), (x * .72, 3.15, 1.53), .053, .076, INK)
    for side in (-1, 1):
        g.board("中野青果", 0, 3.01, side * 1.54, 3.67, .68, .40, side, RUST)
    # Existing bench footprint forms the stall's shallow display counter.
    for x in (-1.28, 1.28):
        g.box(x, .306, 1.18, .14, .60, .37, "67472e")
    g.box(0, .52, 1.18, 2.78, .13, .43, "86634a")
    g.box(0, .66, 1.18, 2.83, .16, .43, "b18453")
    for j in range(16):
        g.box(j * .174 - 1.305, .39, 1.378, .15, .37, .028,
              ("785139", "825b3a", "936844")[j % 3])
    rng = random.Random(29)
    for i, (name, fruit_colors, radius) in enumerate((
        ("りんご", ("ab452c", "ba5838", "cc6e42"), .061),
        ("みかん", ("c87629", "de9032", "e8a848"), .060),
        ("キャベツ", ("55804b", "7d9558", "a2aa6e"), .080),
    )):
        x = (i - 1) * .91
        g.packed_crate(x, .74, 1.15, .79, .53, "a27a4b")
        g.box(x,.904,1.15,.72,.045,.46,"ab996c")
        for row in range(3):
            for column in range(5):
                px = x + (column - 2) * .131 + rng.uniform(-.015, .015)
                pz = 1.13 + (row - 1) * .128 + rng.uniform(-.016, .016)
                size = radius * rng.uniform(.86, 1.14)
                g.fruit(px,.926+size*(.66 if i==1 else .79),pz,size,rng.choice(fruit_colors))
        g.box(x, .815, 1.425, .61, .14, .029, "d6c9a7")
        g.letter(name, x, .815, 1.355, 1, .067, INK)
    g.lens(0, 2.376, .12, 1.26, .11)
    return g


def frontage():
    g = Building(0)
    for x in (-5, -1.05, 1.05):
        g.box(x, 1.255, 0, .11, 2.51, .23, INK)
        g.box(x, .12, 0, .17, .24, .24, STEEL)
    g.box(-3.025, 2.47, 0, 3.95, .27, .345, INK)
    g.box(-3.025, 2.59, 0, 3.95, .048, .37, STEEL)
    g.box(0, 2.465, 0, 2.25, .26, .31, TEAL)
    for x in (-1.057, 1.057):
        g.box(x, 2.40, .01, .073, .25, .29, TRIM)
        g.box(x, .044, 0, .164, .084, .49, STEEL)
    for x in (-1.015, 1.015):
        g.box(x, 2.328, 0, .067, 4.57, .14, TRIM)
        g.box(x, 4.515, .014, .125, .18, .19, INK)
    g.box(0, 4.63, 0, 2.18, .10, .21, TEAL)
    g.box(0, 4.54, 0, .38, .22, .23, STEEL)
    for x in (-.32, .32):
        g.beam((x, 4.51, .022), (x, 2.50, .022), .021, .023, INK)
    # Flush sill and an overhead sign mark the passage as the door lifts along its guides.
    for x in (-.71, -.36, 0, .36, .71):
        g.box(x, .008, 0, .227, .015, .52, CREAM)
    for side in (-1, 1):
        g.board("横戸", 0, 2.88, .18 * side, 1.70, .52, .31, side, TEAL)
        g.board("花店", -3.025, 2.89, .12 * side, 1.98, .52, .28, side, "6a575e")
    g.lens(0, 2.42, .174, .63, .09)
    return g


def gate():
    g = Building(0)
    g.box(0, 1.18, 0, 1.97, 2.34, .17, "8c6042")
    for j in range(12):
        x = -.9075 + .165 * j
        g.box(x, 1.17, 0, .155, 2.23, .196,
              ("9a6744", "956346", "a5744e", "906447")[j % 4])
    for side in (-1, 1):
        for y in (.19, 2.16):
            g.box(0, y, side * .098, 1.94, .115, .024, TEAL)
        g.beam((-.89, .23, side * .112), (.89, 2.09, side * .112), .091, .027, TEAL)
        g.box(.72, 1.12, side * .113, .20, .27, .025, INK)
        g.box(.72, 1.13, side * .145, .105, .054, .050, TRIM)
        for x in (-.91, .91):
            g.box(x, 2.151, side * .117, .037, .037, .014, CREAM)
            g.box(x, .191, side * .117, .037, .037, .014, CREAM)
    return g


def shutter():
    g = Building(0)
    g.box(0, 1.172, 0, 3.855, 2.28, .027, "566662")
    # A corrugated skin carries a shallow existing fold near a braced lower rail.
    for i in range(21):
        y = .051 + .108 * i

        def point(j, h, depth):
            x = -1.917 + .3195 * j
            dent = -.081 * math.exp(-((x + .27) / .66) ** 2 - ((h - 1.12) / .44) ** 2)
            return x, h + .10 * dent, depth + dent

        for j in range(12):
            for h0, h1, a, b, shade in (
                (y - .049, y - .016, .022, .084, "87948c"),
                (y - .016, y + .033, .084, .084, "6f817c"),
                (y + .033, y + .054, .084, .018, "465e59"),
            ):
                for side in (-1, 1):
                    g.face([point(j, h0, a * side), point(j + 1, h0, a * side),
                            point(j + 1, h1, b * side), point(j, h1, b * side)], shade)
    for y in (.09, 2.29):
        g.box(0, y, 0, 3.85, .149, .17, INK)
    return g


def boarding_point():
    g = Building(0)
    # Beams sit over the existing reception awning, outside the bus path.
    for x in (.98, 3.18):
        g.beam((x, 2.43, .76), (x, 4.03, .76), .105, .114, TEAL)
    for side in (-1, 1):
        g.board("バス乗車口", 2.08, 3.76, .76 + side * .11, 3.56, .76, .41, side, TEAL)
    g.lens(2.08, 3.34, .76, 1.54, .14)
    # Floor paint points from the walkable curb to the primary bus's door.
    for z in (-.58, .58):
        g.box(-2.06, .018, z, 2.63, .012, .081, CREAM)
    g.box(-1.49, .018, 0, 1.13, .012, .24, CREAM)
    g.face([(-1.28, .025, -.40), (-.61, .025, 0), (-1.28, .025, .40)], CREAM)
    for x in (-3.23, -2.97, -2.71):
        g.box(x, .018, 0, .089, .012, 1.045, TRIM)
    return g


def impact_audio():
    rng = random.Random(157)
    rate = 32000
    samples = array("h")
    previous_noise = 0
    modes = ((83, .23, .072), (169, .25, .162), (263, .17, .21), (401, .083, .103),
             (651, .10, .108), (1146, .058, .078), (1872, .039, .139), (2863, .027, .070))
    for index in range(int(rate * .72)):
        t = index / rate
        noise = rng.uniform(-1, 1)
        contact = (noise - previous_noise) * .48 * math.exp(-t / .009)
        previous_noise = noise
        steel = sum(
            math.sin(math.tau * frequency * t + 3.5 * math.exp(-t / .018)) *
            math.exp(-t / decay) * gain
            for frequency, gain, decay in modes
        )
        # Loose corrugations rattle after the first heavy contact.
        rattle = sum(noise * gain * math.exp(-(t - delay) / .009)
                     for delay, gain in ((.039, .23), (.083, .17), (.14, .094)) if t >= delay)
        envelope = min(1, t * 1800, (.72 - t) * 40)
        samples.append(round(math.tanh((contact + steel + rattle) * 1.15) * envelope * 30000))
    with wave.open(str(OUT / "marketShutterImpact.wav"), "wb") as clip:
        clip.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        clip.writeframes(samples.tobytes())


if __name__ == "__main__":
    for name, asset in (("marketProduceCanopy", canopy()), ("marketPassageFrame", frontage()),
                        ("marketGateSlab", gate()), ("marketNeighborShutter", shutter()),
                        ("marketBoardingPoint", boarding_point())):
        asset.write(name)
    district, _, _, side_stall = arcade()
    district.write("landmark0")
    side_stall.write("landmark0Stall")
    impact_audio()
