"""Game-space surfaces for the apples, citrus and greens displayed in the market."""
from math import sin, cos, tau


def produce(x, y, z, radius, color):
    red, green, blue = bytes.fromhex(color)
    leafy = green > red * 1.04
    citrus = red > green and green > blue * 1.8 and green > red * .65
    phase = 23*x + 11*z
    rings = []
    # Raised shoulders and a recessed crown distinguish fruit in silhouette.
    for level, width in ((-.84,.33),(-.61,.73),(-.18,.97),(.34,1),(.66,.81),(.79,.43),(.61,.13)):
        ring = []
        for i in range(10):
            a = tau*i/10 + phase
            lobe = 1 + (.048 if leafy else .029)*cos(5*a+phase)
            ring.append((x + radius*width*lobe*cos(a),
                         y + radius*(level+.044*width*sin(3*a))*(.78 if citrus else 1),
                         z + radius*width*lobe*sin(a)))
        rings.append(ring)
    yield rings[0][::-1], color, True
    for lower, upper in zip(rings, rings[1:]):
        for i in range(10):
            yield [lower[i-1],lower[i],upper[i],upper[i-1]], color, True
    yield rings[-1], "596438" if leafy else "765439", True
    if citrus:
        return
    for n in range(3 if leafy else 1):
        a = phase + tau*n/3
        def point(u,v,h):
            return x+radius*(cos(a)*u-sin(a)*v), y+radius*h, z+radius*(sin(a)*u+cos(a)*v)
        start, mid, tip = point(.01,0,.63), point(.44,0,.98), point(.93,.04,.83)
        for side,tint in ((-1,"5f793f"),(1,"84904d")):
            edge = point(.42,side*.19,.87)
            yield [start,edge,mid],tint,False
            yield [mid,edge,tip],tint,False
