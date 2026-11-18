"""Opaque skin, iris and lip colours shared by all facial shapes in the body atlas."""
import numpy as np

# Small atlas islands have a gutter so the mobile mip chain cannot read a neighbour.
IRIS = (281, 593, 437, 748)
MOUTH = (463, 608, 546, 736)
SCLERA = (555, 589, 692, 647)
INKS = (558, 658, 692, 746)
INK_NAMES = (
    'lash', 'brow', 'crease', 'white', 'wetline', 'lip', 'tooth', 'tongue',
    'frame', 'frame_light', 'frame_shadow', 'rim',
)


def color(value):
    from PIL import ImageColor
    return np.array(ImageColor.getrgb(value), dtype=float)


def blend(first, second, amount):
    return first + (second - first) * amount


def skin_layer(c, xyz, theta, index):
    """A continuous skin base under the physical cap, lids, nose and ears."""
    from PIL import Image
    x, _, z = xyz.transpose(2, 0, 1) / c['k']
    row = c['floor'] - z
    mid = (143, 170, 176, 172, 176, 166)[index]
    front = np.maximum(0., np.cos(theta))
    skin = color(c['skin'])
    base = blend(skin, color('#fff4dd'), .21)
    pearl = np.exp(-((x / 51) ** 2 + ((row - mid - 9) / 39) ** 2))
    shadow = .12 + .18 * (1 - front) + .12 * np.clip((row-mid-26)/31, 0, 1)
    result = blend(base, skin * [.94, .79, .78], shadow[..., None])
    result = blend(result, color('#fff2dc'), (.32 * pearl * front)[..., None])
    for side in (-1, 1):
        cheek = np.exp(-((x - side * 45) / 17) ** 2 - ((row - mid - 17) / 8) ** 2)
        result = blend(result, blend(skin, color('#de8581'), .84), (.50 * cheek * front)[..., None])
        for j in range(3):
            dx, dy = x-side*(43+4*j), row-mid-16-(j%2)*1.1
            dash = np.exp(-((dx-.46*dy)/.54)**2 - (dy/1.8)**2)
            result = blend(result, color('#cb807a'), (.41*dash*front)[..., None])
    return Image.fromarray(np.uint8(np.clip(result, 0, 255)))


def ink_uv(name):
    x0,y0,x1,y1 = INKS
    slot = INK_NAMES.index(name)
    return (x0+(slot%4+.5)*(x1-x0)/4, y0+(slot//4+.5)*(y1-y0)/3)


def paint_features(atlas, c):
    from PIL import Image
    x0,y0,x1,y1 = IRIS
    x,y = np.meshgrid(np.linspace(-1,1,x1-x0+1), np.linspace(-1,1,y1-y0+1))
    radius = np.hypot(x, y)
    angle = np.arctan2(y, x)
    hue = color(c['iris'])
    lower = np.clip((y+.68)/1.56,0,1)
    field = blend(hue * [.44,.37,.46], np.minimum(255,hue*[1.36,1.26,1.02]+[47,45,34]), lower[...,None])
    if c['name']=='Nagi':
        # Upper wine and lower amber are sampled on the turnaround at
        # (243,136), (241,141), (243,151) and (243,155), at 1,250px width.
        stops=(-1.,-.54,-.10,.48,.77,1.)
        pigment=((72,33,41),(116,48,44),(142,62,15),(252,178,25),(255,207,55),(255,222,79))
        field=np.stack([np.interp(y,stops,[p[k] for p in pigment]) for k in range(3)],axis=-1)
    filaments = (np.sin(24*angle+3*radius)*.5 + np.sin(37*angle-5*radius)*.35)
    field += (8 * filaments * np.exp(-((radius-.77)/.21)**2) * (.62+.38*y))[...,None]
    ring = np.clip((radius-.86)/.125,0,1)**1.5
    field = blend(field, hue*.32 + [9,4,14], ring[...,None])
    # The soft pupil sits higher in the iris, leaving a bright crescent at its base.
    pupil = np.hypot(x/.40,(y+.14)/.57)
    pupil_fade = np.clip((1.08-pupil)*8,0,1)
    field = blend(field,hue*.21+[9,4,14],pupil_fade[...,None])
    for cx,cy,rx,ry,brightness,shade in [
        (-.32,-.42,.245,.23,1,'#fffbee'),(-.10,-.63,.066,.073,.92,'#fff4e6'),
        (.31,.56,.10,.064,.91,'#fff7cc'),(.47,.45,.046,.045,.81,'#fff0b0'),
    ]:
        distance = np.hypot((x-cx)/rx,(y-cy)/ry)
        field = blend(field,color(shade),(brightness*np.clip((1.07-distance)*8,0,1))[...,None])
    # A narrow transition at the side of the limbus samples cleanly even
    # when the entire iris is under 20 screen pixels. Keep the lower amber arc.
    edge = np.clip((radius-.925)/.075,0,1) * np.clip(1.55*abs(x)-.59,0,1)
    field = blend(field,color('#f5e4dd'),edge[...,None])
    def island(field, x0, y0, gutter):
        pixels=np.uint8(np.clip(field,0,255))
        padded=np.pad(pixels,((gutter,gutter),(gutter,gutter),(0,0)),mode='edge')
        atlas.paste(Image.fromarray(padded),(x0-gutter,y0-gutter))
    island(field,x0,y0,5)
    x0,y0,x1,y1 = SCLERA
    x,t=np.meshgrid(np.linspace(-1,1,x1-x0+1),np.linspace(0,1,y1-y0+1))
    eye_white=blend(color('#eedbd7'),color('#fff4e7'),(.68+.29*np.sin(np.pi*t))[...,None])
    upper=np.exp(-(t/.16)**2)
    eye_white=blend(eye_white,color('#9f8192'),(.30*upper)[...,None])
    # The lower edge changes from a warm tear duct to a firmer outer lid.
    # Its colour lives inside the white surface, so no fine line can float.
    outer=np.clip((x+.5)/1.12,0,1)
    width=.030+.044*outer
    rim_ink=np.exp(-((1-t)/width)**2) * (.23+.62*outer)
    eye_white=blend(eye_white,color('#98696c'),rim_ink[...,None])
    island(eye_white,x0,y0,4)
    x0,y0,x1,y1 = MOUTH
    x,t=np.meshgrid(np.linspace(-1,1,x1-x0+1),np.linspace(0,1,y1-y0+1))
    back=blend(color('#442232'),color('#b94c59'),(.12+.76*t+.08*(1-x*x))[...,None])
    # Print the continuous edge of the incisors and the raised tongue on the
    # same curved surface. Both margins are softened by approximately one texel.
    upper=.047+.020*x*x
    half=np.clip(1-((x+.042)/.85)**2,0,1)**.67
    tooth_fraction=.181 if c['name']!='Mio' else .39
    enamel_bottom=upper+tooth_fraction*half
    tooth_mask=np.clip((t-upper)/.017,0,1)*np.clip((enamel_bottom-t)/.020,0,1)
    tooth=blend(color('#ffe6d6'),color('#fff9ec'),np.clip(.69+.24*(1-x*x)-t,0,1)[...,None])
    field=blend(back,tooth,tooth_mask[...,None])
    tongue_edge=.51+.32*x*x+.022*np.cos(2*np.pi*x)
    tongue_mask=np.clip((t-tongue_edge)/.029,0,1)*np.clip((1-t)/.076,0,1)
    tongue=blend(color('#d56576'),color('#ff9a8d'),np.clip(.92-.58*(t-.52)**2-.48*x*x,0,1)[...,None])
    field=blend(field,tongue,tongue_mask[...,None])
    lip_ink=np.clip((t-.952)/.048,0,1)*.54
    field=blend(field,color('#9b535b'),lip_ink[...,None])
    island(field,x0,y0,4)
    skin,hair = color(c['skin']),color(c['hair'])
    values = (
        blend(color('#312335'), hair*.35, .16),
        blend(hair*.61, color('#6d443d'), .20),
        blend(skin*.69, color('#b17476'),.46),
        color('#fff4e9'), blend(skin, color('#f2b3af'),.50),
        color('#a6535b'),color('#fff6dd'),color('#ee8490'),
        color('#ce95a5'),color('#ffe3ce'),color('#905c77'),blend(hair*.65,color('#b47a72'),.62),
    )
    x0,y0,x1,y1 = INKS
    for i,value in enumerate(values):
        xa=round(x0+i%4*(x1-x0)/4); xb=round(x0+(i%4+1)*(x1-x0)/4)
        ya=round(y0+i//4*(y1-y0)/3); yb=round(y0+(i//4+1)*(y1-y0)/3)
        atlas.paste(tuple(np.uint8(value)), (xa,ya,xb,yb))

