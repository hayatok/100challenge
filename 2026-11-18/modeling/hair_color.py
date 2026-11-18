"""Satin swatch for shaped locks. U runs around a lock, V runs root to tip."""
import numpy as np


def lock_tile(character):
    def rgb(key):
        value = character[key].lstrip('#')
        return np.array([int(value[k:k + 2], 16) for k in (0, 2, 4)])
    u, v = np.meshgrid(np.linspace(0, 1, 150), np.linspace(0, 1, 230))
    if character['name'] == 'Nagi':
        # Sampled down the centre of a broad lock on the three-view artwork.
        # The satin band runs around the head; only its narrow crease darkens.
        rows = (21, 44, 57, 70, 82, 97, 119, 148, 174, 199)
        colours = ((63,45,97),(87,67,135),(97,72,147),(130,96,168),
                   (99,75,145),(76,58,116),(71,53,110),(65,48,99),
                   (54,37,78),(36,24,52))
        row = 20+180*v+3.4*np.cos(2*np.pi*u+.6)
        band = np.stack([np.interp(row, rows, [c[j] for c in colours])
                         for j in range(3)], axis=-1)
        crease = .73+.27*np.sin(np.pi*(.02+.96*u))**.45
        return band*crease[:,:,None]
    # Broad value planes survive minification. The painted highlight follows the
    # ridge, rolls around the section and fades before either end.
    base, light = rgb('hair'), rgb('bright')
    wave = .033 * np.sin(4.6 * v + .1)
    crest = np.exp(-((u - .46 - wave) / .245) ** 2)
    satin = np.exp(-((v - .35 + .065 * np.cos(6 * u)) / .14) ** 2)
    highlight = (.58 + .47 * satin) * crest
    shadow = .64 + .36 * np.sin(np.pi * np.clip((u + .06) / 1.13, 0, 1)) ** .75
    value = base * shadow[:, :, None] + (light - base) * highlight[:, :, None]
    return np.clip(value, 0, 255)


def hair_panels(index, character, art):
    """Front and rear paint islands contain hair only; the face remains separate."""
    from PIL import Image
    from scipy.ndimage import binary_opening, distance_transform_edt, gaussian_filter
    from forms import CAST
    if index == 0:
        return turnaround_hair(art)
    c=character
    hair = np.array([int(c['hair'][j:j+2],16) for j in (1,3,5)],float)
    def sample(file,cx,character,rear=False):
        from forms import station_width
        top,bottom=character['stations'][0][0],character['stations'][-1][0]
        source=Image.open(art/file).convert('RGB')
        scale=source.width/1250
        rect=((cx-122)*scale,(top-2)*scale,(cx+122)*scale,(bottom+3)*scale)
        pixels=np.asarray(source.transform((512,320),Image.Transform.EXTENT,rect,Image.Resampling.BICUBIC),float)
        r,g,b=pixels.transpose(2,0,1)
        x,y=np.meshgrid(np.linspace(-122,122,512),np.linspace(top-2,bottom+3,320))
        rad=np.array([station_width(character,k) for k in y[:,0]])[:,None]
        valid=abs(x)<rad*.99
        if index==0 or rear:valid&=(b>r*1.08)&(b>g*1.15)&(r<160)&(g<143)
        elif index==1:valid&=(r>170)&(g>128)&(r-g<78)&(r>g)&(g>b+9)&(b>105)
        elif index==2:valid&=(b>r*.98)&(b>g*1.14)&(r>68)
        elif index==3:valid&=(r>g*1.30)&(g>b*1.22)&(r>108)&(b<.43*r)
        elif index==4:valid&=(r>g*1.2)&(b>g*1.10)&(r>b*1.12)
        else:valid&=(b>r*1.12)&(b>g*1.035)&(g>r*.98)
        if not rear:
            # Exclude the facial features at the boundary with the fringe,
            # including An's orange eye and Nene's coloured glasses.
            valid&=(y<[124,150,151,148,151,146][index])|(abs(x)>[64,64,56,62,65,61][index])
        valid=binary_opening(valid,iterations=2)
        dist,inds=distance_transform_edt(~valid,return_indices=True)
        colour=pixels[tuple(inds)]
        # Lose high-frequency features immediately outside the observed hair.
        # Nearest-colour extension by itself draws horizontal bands across a
        # rolled side-lock where the reference shows skin or background.
        soft=gaussian_filter(colour,sigma=(7,7,0))
        edge=np.clip(dist/8,0,1)[:,:,None]
        colour=colour*(1-edge)+soft*edge
        # A broad knot/visor hides a section of some haircuts; the local colour
        # fades into the hair swatch in those unobserved areas.
        if not rear:
            fade=np.clip((dist-8)/57,0,.79)[:,:,None]
            colour=colour*(1-fade)+hair*fade
        return colour
    front=sample('nagi-turnaround.png' if index==0 else 'racers.png',c['cx'],c)
    # The five portraits show their front. Continue each runner's own
    # colours around the scalp; do not stamp the hero's bob on the rear.
    from scipy.ndimage import map_coordinates
    angles, along = np.meshgrid(np.linspace(-np.pi,np.pi,512),np.linspace(0,1,320))
    frequency=(0,9,8,10,9,8)[index]
    bend=(0,.35,-.37,.44,.29,-.46)[index]
    phase=(angles/(2*np.pi)*frequency+bend*np.sin(np.pi*along)
           +.18*np.sin(2*angles+1.1*along))%1
    swatch=lock_tile(c)
    rear=np.stack([map_coordinates(swatch[:,:,j],[229*along,149*phase],order=1)
                   for j in range(3)],axis=-1)
    from forms import station_width
    top,bottom=c['stations'][0][0],c['stations'][-1][0]
    rad=np.array([station_width(c,top+(bottom-top)*v) for v in along[:,0]])[:,None]
    local_x=rad*np.sin(angles)
    front_under=np.stack([map_coordinates(front[:,:,j],
                          [319*along,(local_x+122)/244*511],order=1,mode='nearest')
                          for j in range(3)],axis=-1)
    observed=np.clip((1.13-np.abs(angles))/.68,0,1)
    observed=(observed*observed*(3-2*observed)*.80)[:,:,None]
    rear=rear*(1-observed)+front_under*observed
    out=np.concatenate((front,rear),axis=1)
    # The source silhouette occupies only a few pixels at the crown. Fade
    # into the same local crown colour there so stretching its antialiased
    # outline cannot turn one highlight into a fan of pale stripes.
    t=np.clip((np.arange(out.shape[0])-7)/22,0,1)
    t=(t*t*(3-2*t))[:,None,None]
    crown=.70*hair+.30*np.array([int(c['bright'][j:j+2],16) for j in (1,3,5)])
    out=out*t+crown*(1-t)
    return Image.fromarray(np.uint8(np.clip(out,0,255)))


def turnaround_hair(art):
    """One cylindrical paint island, blended over measured front, profile and rear views."""
    from PIL import Image
    from scipy.ndimage import binary_opening, distance_transform_edt, gaussian_filter, map_coordinates
    from forms import CAST, side_edges, station_width
    width, height = 1024, 320
    image = Image.open(art/'nagi-turnaround.png').convert('RGB')
    image = np.asarray(image.resize((1250, round(1250*image.height/image.width)), Image.Resampling.LANCZOS), float)
    angle, row = np.meshgrid(np.linspace(-np.pi,np.pi,width), np.linspace(18,203,height))
    radius = np.array([station_width(CAST[0], v) for v in row[:,0]])[:,None]
    x = radius*np.sin(angle)
    edges = np.array([side_edges(v) for v in row[:,0]])
    front = edges[:,0,None]
    rear = edges[:,1,None]
    y = (front+rear)/2-(rear-front)*np.cos(angle)/2
    # Extend only the colours of the observed hair, so the red bow and ear
    # cannot be painted on the opposite side of the head.
    def paint(left, right, sample_x, exclude):
        crop = image[:205,left:right]
        rr,gg,bb = crop.transpose(2,0,1)
        local_x, local_y = np.meshgrid(np.arange(left,right),np.arange(205))
        hair = (bb>rr*1.12)&(bb>gg*1.23)&(rr<160)&(gg<145)&~exclude(local_x,local_y)
        hair = binary_opening(hair,iterations=1)
        distance, indices = distance_transform_edt(~hair,return_indices=True)
        ink = crop[tuple(indices)]
        fade = np.clip(distance/12,0,1)[:,:,None]
        ink = ink*(1-fade)+gaussian_filter(ink,(6,6,0))*fade
        return np.stack([map_coordinates(ink[:,:,channel],[row,sample_x-left],order=1,mode='nearest')
                         for channel in range(3)],axis=-1)
    front_paint = paint(151,390,273+x,lambda x,r:(r>121)&(abs(x-273)<54))
    mirror = paint(151,390,273-abs(x),lambda x,r:(r>121)&(abs(x-273)<54))
    f = np.clip((x-24)/14,0,1)[:,:,None]
    front_paint = front_paint*(1-f)+mirror*f
    rear_paint = paint(858,1092,977+abs(x),lambda x,r:(r>199))
    # The ribbon and ear occupy most of one temple. Carry the measured
    # purple satin through that quarter along the same root-to-tip flow.
    phase = abs(angle)*3.4-.30*np.sin(np.pi*(row-21)/177)
    u = phase%1
    swatch = lock_tile(CAST[0])
    v = np.clip((row-20)/180,0,1)
    side_paint = np.stack([map_coordinates(swatch[:,:,k],
                           [229*v,149*u],order=1,mode='nearest') for k in range(3)],axis=-1)
    def ramp(lo,hi):
        t = np.clip((abs(angle)-lo)/(hi-lo),0,1)
        return (t*t*(3-2*t))[:,:,None]
    f = ramp(.45,1.16)
    blended = front_paint*(1-f)+side_paint*f
    f = ramp(2.05,2.64)
    blended = blended*(1-f)+rear_paint*f
    # The source has a second apparent crown painted into the front
    # projection. On the physical top the locks share one part. Fade that
    # projected part into longitudinal satin before the frontal fringe.
    coverage=np.clip((row-24)/43,0,1)[:,:,None]
    coverage=.075+.925*coverage*coverage*(3-2*coverage)
    blended=blended*coverage+side_paint*(1-coverage)
    # At the pole, all longitudes meet physically. A smooth common crown
    # colour keeps the upper skin closed and the crown part inconspicuous.
    pole = np.clip((row-23)/12,0,1)[:,:,None]
    blended = blended*pole + np.array((76,58,122))*(1-pole)
    return Image.fromarray(np.uint8(np.clip(blended,0,255)))
