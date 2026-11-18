"""Paint the albedo atlas from the supplied design sheets. Requires Pillow, NumPy and SciPy."""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageColor, ImageFont
from scipy.ndimage import binary_fill_holes, distance_transform_edt, map_coordinates
from forms import CAST, PALETTE, profile
from face_paint import skin_layer, paint_features
from hair_color import lock_tile, hair_panels
HERE=Path(__file__).resolve().parent
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else HERE/'textures'
OUT.mkdir(parents=True,exist_ok=True)
def source(name):
    return np.asarray(Image.open(HERE.parent/'art'/name).convert('RGB'),dtype=float)
turn=source('nagi-turnaround.png')
ratio=turn.shape[1]/1250
def cleaned(im,box,poly):
    x0,y0,x1,y1=(int(v*ratio) for v in box)
    img=im[y0:y1,x0:x1].copy()
    r,g,b=img.transpose(2,0,1)
    bg=(r>222)&(g>207)&(b>187)&(r-g<37)&(g-b<28)
    mask=Image.new('L',(x1-x0,y1-y0))
    ImageDraw.Draw(mask).polygon([(x*ratio-x0,y*ratio-y0) for x,y in poly],fill=255)
    valid=binary_fill_holes(binary_fill_holes(~bg) & (np.asarray(mask)>0))
    idx=distance_transform_edt(~valid,return_distances=False,return_indices=True)
    return img[tuple(idx)],x0,y0
def sample(info,x,y):
    im,x0,y0=info
    return np.stack([map_coordinates(im[:,:,j],np.array([y*ratio-y0,x*ratio-x0]),order=1,mode='nearest') for j in range(3)],axis=-1)
def rgb(v):return tuple(ImageColor.getrgb(v))
def smooth(a,b,x):
    f=np.clip((x-a)/(b-a),0,1)
    return f*f*(3-2*f)
for i,c in enumerate(CAST):
    th,v=np.meshgrid(np.linspace(-np.pi,np.pi,1024),np.linspace(0,1,512))
    xyz=np.array([profile(c,a,b) for a,b in zip(th.flat,v.flat)]).reshape(512,1024,3)
    atlas=Image.new('RGB',(1024,1024))
    skin=skin_layer(c,xyz,th,i).resize((1024,188), Image.Resampling.LANCZOS)
    atlas.paste(skin,(0,324))
    atlas.paste(hair_panels(i,c,HERE.parent/'art'),(0,0))
    draw=ImageDraw.Draw(atlas)
    for k,p in enumerate(PALETTE):
        draw.rectangle((k*32,512,k*32+31,575),fill=c.get(p,p))
    # Competition bib, printed on a warm cloth square with stitched hem and brass pins.
    bib=Image.new('RGB',(256,160),'#f6e7d4'); g=ImageDraw.Draw(bib)
    g.rounded_rectangle((5,5,250,155),13,outline='#b89f97',width=4)
    g.rounded_rectangle((11,11,244,149),9,outline='#ded1be',width=2)
    for xx in [18,238]:
        for yy in [18,142]:
            g.ellipse((xx-4,yy-4,xx+4,yy+4),fill='#68646b');g.ellipse((xx-2,yy-3,xx+1,yy),fill='#f1ebd6')
    font_path='/System/Library/Fonts/Supplemental/Arial Bold.ttf'
    if not Path(font_path).exists():font_path='DejaVuSans-Bold.ttf'
    font=ImageFont.truetype(font_path,143)
    g.text((128,85),f'{i+1:02}',fill='#292c46',font=font,anchor='mm',stroke_width=2)
    atlas.paste(bib,(0,600))
    paint_features(atlas, c)
    if i==0:
        # Original ribbon ink is carried on a genuinely thick, folded bow.
        bow=turn[int(12*ratio):int(137*ratio),int(311*ratio):int(386*ratio)].copy()
        rr,gg,bl=bow.transpose(2,0,1)
        keep=(rr>gg*1.6)&(rr>bl*1.24)
        idx=distance_transform_edt(~keep,return_distances=False,return_indices=True)
        bow=Image.fromarray(bow[tuple(idx)].astype(np.uint8)).resize((154,250),Image.Resampling.LANCZOS)
        atlas.paste(bow,(710,561))
    # The turnaround supplies both unobstructed faces of the athletic jacket.
    # Share its construction seams and zipper with the team recolours.
    coatfront=cleaned(turn,(229,196,318,274),[(245,203),(260,198),(288,197),(300,203),(305,220),(305,240),(311,262),(312,269),(237,269),(235,259),(241,239),(242,221)])
    coatback=cleaned(turn,(930,195,1020,274),[(951,201),(965,197),(988,197),(1002,203),(1006,221),(1009,242),(1015,263),(1011,270),(941,270),(939,260),(946,241),(947,223)])
    ang,tt=np.meshgrid(np.linspace(-np.pi,np.pi,1024),np.linspace(0,1,205))
    zz=125+tt*72
    xx=np.sin(ang)*np.interp(zz,[125,129,138,153,170,181,190,197],[37,39,41,39,36,34,29,18])
    cf=sample(coatfront,273+xx,398-zz);cb=sample(coatback,977-xx,398-zz)
    w=smooth(1.25,1.8,np.abs(ang))[:,:,None]
    coat=cf*(1-w)+cb*w
    if i:
        # Repaint the fabric in team colours, retaining the shadowing and stitch lines.
        lum=coat@np.array([.22,.59,.19])
        ink=lum<116
        factor=np.clip((lum/228),.62,1.2)[:,:,None]
        coat=np.where(ink[:,:,None],np.array(rgb(c['jacket']))*.51,np.array(rgb(c['jacket']))*factor)
    atlas.paste(Image.fromarray(np.uint8(np.clip(coat,0,255))),(0,819))
    # A small satin-hair tile follows each physical lock along its length.
    strand=lock_tile(c)
    atlas.paste(Image.fromarray(np.uint8(np.clip(strand,0,255))),(870,580))
    # Reproject the reference running shoe onto the curved last, then dye its
    # leather to team colours while keeping the three laces and rubber toe guard.
    aa,zz=np.meshgrid(np.linspace(-np.pi,np.pi,688),np.linspace(0,42,56))
    rx=np.interp(zz,[0,4,13,18,24,33,39,42],[25,30,31.5,30,28.5,24,19,17])
    ry=np.interp(zz,[0,4,13,18,24,33,39,42],[36,41,42.5,40.5,36,30,20,16])
    xx=rx*np.sin(aa); yy=np.interp(zz,[0,13,24,33,39,42],[-8,-8,-6,-2,4,5])-ry*np.cos(aa)
    sf=cleaned(turn,(203,343,274,399),[(231,347),(251,347),(262,356),(271,376),(270,396),(207,396),(206,383),(211,368),(215,354)])
    ss=cleaned(turn,(545,346,645,399),[(595,347),(622,351),(632,361),(636,375),(641,385),(638,395),(550,395),(548,383),(552,376),(557,370),(570,364),(576,356)])
    sr=cleaned(turn,(908,345,979,399),[(925,352),(945,348),(960,351),(969,364),(976,390),(972,395),(912,395),(912,384),(918,361)])
    cf=sample(sf,238+xx,398-zz);cs=sample(ss,598+yy,398-zz);cb=sample(sr,944-xx,398-zz)
    w=smooth(.55,1.4,np.abs(aa))[:,:,None];sh=cf*(1-w)+cs*w
    w=smooth(1.82,2.63,np.abs(aa))[:,:,None];sh=sh*(1-w)+cb*w
    if i:
        rr,gg,bb=sh.transpose(2,0,1);mask=smooth(.10,.36,(rr-gg)/(rr+.1))
        dye=np.array(rgb(c['shoe']))*(np.clip(rr/213,.47,1.24)[:,:,None])
        sh=sh*(1-mask[:,:,None])+dye*mask[:,:,None]
    atlas.paste(Image.fromarray(np.uint8(np.clip(sh,0,255))),(0,761))
    atlas.save(OUT/f'{i+1:02}.png',optimize=True)
