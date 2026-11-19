"""Evacuation bus. The two side doors align with the evacuation point at local z=-2."""


def city_bus(batch, x, z, box, rod, wheel):
    ivory = "d6d2bb"
    teal = "376b63"
    darker_teal = "294f4c"
    rubber = "232a2b"
    floor = "4e5551"
    trim = "8c9992"
    yellow = "eab549"
    ceiling = "aaa794"
    light = "fff0bc"
    enamel, tire = 5*16, 6*16
    painted_colors = {ivory, teal, darker_teal, yellow}

    def block(cx, height, cz, width, h, depth, color, tag=None):
        if tag is None:
            tag = enamel if color in painted_colors else 0
        box(x+cx, height, z+cz, width, h, depth, color, tag)

    def surface(points, color, tag=0):
        batch.poly([(x+px, py, z+pz) for px, py, pz in points], color, tag)

    def rail(start, end, radius, color):
        sx, sy, sz = start
        ex, ey, ez = end
        rod((x+sx, sy, z+sz), (x+ex, ey, z+ez), radius, color,
            enamel if color in painted_colors else 0)

    nose, tail = -4.35, 4.35
    door_front, door_back = -2.67, -1.33
    wall = 1.46
    sill, header = 1.64, 2.50

    # The central chassis leaves a stairwell on either side of the aisle.
    block(0, .57, 0, 1.38, .42, 8.28, rubber, tire)
    block(0, .87, 0, 1.52, .11, 8.25, floor)
    block(0, .87, (nose+door_front)/2, 2.76, .11, door_front-nose-.25, floor)
    block(0, .87, (tail+door_back)/2, 2.76, .11, tail-door_back-.25, floor)

    for side in (-1, 1):
        for start, end in ((-4.13, door_front), (door_back, 4.14)):
            center = (start+end)/2
            block(side*1.42, 1.20, center, .08, .88, end-start, teal)
            block(side*1.467, 1.48, center, .025, .106, end-start, ivory)
            block(side*1.467, 1.04, center, .025, .11, end-start, darker_teal)
            block(side*1.423, 1.648, center, .11, .045, end-start, rubber, tire)
            block(side*1.415, 1.617, center, .13, .018, end-start, trim, enamel)

        # The side apertures are open in the opaque street mesh. Rubber seals and
        # narrow strips with a smoked tint give each opening a framed window edge.
        for start, end in ((-4.13,-3.98), (-2.83,door_front), (door_back,-1.18),
                           (.01,.12), (1.29,1.40), (2.57,2.68), (3.95,4.14)):
            block(side*1.42, (sill+header)/2, (start+end)/2,
                  .08, header-sill, end-start, rubber, tire)
        for start, end in ((-3.98,-2.83), (-1.18,.01), (.12,1.29), (1.40,2.57), (2.68,3.95)):
            center = (start+end)/2
            block(side*1.412, 2.433, center, .063, .085, end-start, "4f6161")
            block(side*1.414, 2.46, center, .065, .019, end-start, "9caea3")
            block(side*1.416, 1.958, center, .039, .026, end-start, trim)

        block(side*1.42, 2.564, 0, .082, .135, 8.27, ivory)
        block(side*1.463, 2.522, 0, .018, .046, 8.27, darker_teal)
        for dz in (-3.47, 2.70):
            wheel(x+side*1.366,.52,z+dz,segments=32,tire=tire)
            block(side*1.29, .67, dz+.51, .36, .35, .075, rubber, tire)
        for cz in (-3.86, 3.85):
            block(side*1.447, 1.22, cz, .067, .086, .18, "d39e54", enamel)
        for cz in (.70,3.60):
            block(side*1.461, 1.23, cz, .008, .29, .70, darker_teal)
            block(side*1.465, 1.23, cz, .009, .268, .678, teal)
            block(side*1.473, 1.32, cz+.20, .014, .038, .12, trim, enamel)

        # Recess the folded door leaves and expose the three stair nosings.
        for edge in (door_front, door_back):
            block(side*1.418, 1.50, edge, .118, 2.035, .085, yellow)
            inward = 1 if edge == door_front else -1
            block(side*1.265, 1.01, edge+inward*.075, .21, .98, .095, rubber)
            block(side*1.285, 2.008, edge+inward*.076, .20, 1, .075, "41575b")
            rail((side*1.28,.80,edge+inward*.14), (side*.79,1.34,edge+inward*.14), .028, yellow)
            rail((side*.79,1.34,edge+inward*.14), (side*.79,2.31,edge+inward*.14), .028, yellow)
        for outer, inner, top in ((1.50,1.26,.43), (1.26,1.02,.60), (1.02,.75,.77)):
            block(side*(outer+inner)/2, top-.09, -2, outer-inner, .18, 1.24, floor)
            block(side*(outer-.026), top+.008, -2, .052, .016, 1.20, yellow)
        block(side*1.32, 2.489, -2, .19, .082, 1.27, rubber)
        block(side*1.30, 2.442, -2, .105, .028, 1.10, light, 15*16)

        # Seat backs sit behind the window reveals with space left for the aisle.
        for cz in (-.91,.29,1.49,2.69,3.78):
            block(side*.95, 1.02, cz, .43, .19, .33, trim)
            block(side*.95, 1.24, cz-.08, .69, .135, .51, "4b6263")
            surface([(side*.605,1.26,cz+.12),(side*1.30,1.26,cz+.12),
                     (side*1.30,1.78,cz+.25),(side*.605,1.78,cz+.25)], "67817d")
            block(side*.95, 1.77, cz+.251, .69, .085, .10, "405c5c")
        rail((side*.63,2.37,-1.32), (side*.63,2.37,3.98), .025, yellow)
        for cz in (-1.16,1.47,3.88):
            rail((side*.63,.94,cz), (side*.63,2.41,cz), .023, trim)
        block(side*.75, 2.51, 1.30, .17, .025, 4.80, light, 15*16)

        # Rounded shoulders connect the roof to the window pillars.
        for (a, ay), (b, by), color in (
            ((wall,2.62),(1.35,2.75),ivory), ((1.35,2.75),(1.11,2.84),trim),
        ):
            surface([(side*a,ay,-4.12),(side*a,ay,4.12),
                     (side*b,by,4.12),(side*b,by,-4.12)], color, enamel)

    block(0, 2.628, 0, 2.67, .19, 8.24, ceiling)
    surface([(-1.11,2.84,-4.12),(1.11,2.84,-4.12),
             (1.11,2.84,4.12),(-1.11,2.84,4.12)], ceiling, enamel)
    block(0, 2.89, .70, 1.34, .14, 2.10, trim, enamel)
    for cz in (.08,.30,.52,.74,.96,1.18):
        block(0, 2.977, cz, 1.04, .034, .075, rubber)

    for end in (-1, 1):
        edge = end*4.28
        surface([(-1.11,2.84,end*4.12),(1.11,2.84,end*4.12),
                 (1.30,2.67,end*4.35),(-1.30,2.67,end*4.35)], ceiling, enamel)
        block(0, 1.19, edge, 2.60, .86, .14, teal)
        block(0, .80, edge, 2.58, .12, .14, rubber)
        block(0, 1.47, end*4.354, 2.53, .10, .028, ivory)
        block(0, 2.592, edge, 2.60, .155, .14, ivory)
        block(0, 2.515, edge, 2.62, .042, .15, rubber)
        block(0, 1.664, edge, 2.65, .063, .15, rubber)
        block(0, 2.094, edge, .058, .82, .09, rubber)
        for side in (-1,1):
            surface([(side*1.46,2.62,end*4.12),(side*1.11,2.84,end*4.12),
                     (side*1.30,2.67,end*4.35)], ivory, enamel)
            points = [(side*1.46,1.63,end*4.12),(side*1.30,1.63,edge),
                      (side*1.30,2.64,edge),(side*1.46,2.62,end*4.12)]
            surface(points, rubber, tire)
            surface([(side*1.46,.80,end*4.12),(side*1.30,.80,edge),
                     points[1],points[0]], teal, enamel)
            block(side*1.02, 1.25, end*4.348, .44, .23, .065, rubber)
            block(side*1.04, 1.252, end*4.385, .32, .122, .018, light if end<0 else "b04f40")
            block(side*.994, 1.145, end*4.385, .215, .045, .024, yellow)
        if end > 0:
            block(0, 1.12, 4.355, 1.28, .49, .025, darker_teal)
            for height in (1.01,1.09,1.17,1.25):
                block(0, height, 4.372, 1.17, .033, .025, rubber)

    # The driver cabin carries details legible from a low viewpoint.
    block(0, 1.477, -4.12, 2.40, .22, .25, rubber)
    block(.85, 1.52, -3.18, .54, .46, .23, "526e69")
    rail((.79,1.42,-3.92), (.82,1.70,-3.70), .047, trim)
    ring = ((.63,1.70,-3.76),(.67,1.78,-3.66),(.82,1.81,-3.61),
            (.97,1.78,-3.66),(1.01,1.70,-3.76),(.97,1.62,-3.84),
            (.82,1.59,-3.90),(.67,1.62,-3.84))
    for start,end in zip(ring, ring[1:]+ring[:1]):
        rail(start, end, .024, rubber)
    block(0, 2.60, -4.353, 1.54, .125, .038, rubber)
    for cx in (-.48,-.24,0,.24,.48):
        block(cx, 2.601, -4.376, .135, .044, .013, yellow)
    for side in (-1,1):
        rail((side*.63,1.68,-4.358), (side*.98,1.89,-4.358), .018, rubber)
        rail((side*1.37,2.38,-4.05), (side*1.475,2.23,-4.30), .028, rubber)
        block(side*1.475, 2.08, -4.30, .14, .268, .15, rubber, tire)
        block(side*1.475, 2.08, -4.215, .105, .211, .023, trim, enamel)
