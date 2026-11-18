"""Satin swatch for shaped locks. U runs around a lock, V runs root to tip."""
import numpy as np


def lock_tile(character):
    def rgb(key):
        value = character[key].lstrip('#')
        return np.array([int(value[k:k + 2], 16) for k in (0, 2, 4)])
    u, v = np.meshgrid(np.linspace(0, 1, 150), np.linspace(0, 1, 230))
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
    rear=sample('nagi-turnaround.png',977,CAST[0],True)
    # The three-view drawing exposes this side free of the red bow. Mirroring
    # the clear half preserves the shape of the central down-swept brushwork.
    rear[:,:256]=rear[:,256:][:,::-1]
    if index:
        grey=rear@np.array((.22,.59,.19))
        rear=np.clip(hair[None,None,:]+(grey[:,:,None]-48)*.82,0,255)
    out=np.concatenate((front,rear),axis=1)
    # The source silhouette occupies only a few pixels at the crown. Fade
    # into the same local crown colour there so stretching its antialiased
    # outline cannot turn one highlight into a fan of pale stripes.
    t=np.clip((np.arange(out.shape[0])-7)/22,0,1)
    t=(t*t*(3-2*t))[:,None,None]
    crown=.70*hair+.30*np.array([int(c['bright'][j:j+2],16) for j in (1,3,5)])
    out=out*t+crown*(1-t)
    return Image.fromarray(np.uint8(np.clip(out,0,255)))
