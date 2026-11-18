"""Paint the albedo atlas from the supplied design sheets. Requires Pillow, NumPy and SciPy."""
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageColor, ImageFont
from scipy.ndimage import distance_transform_edt, map_coordinates
from forms import CAST, PALETTE, EYES, FRONT_MASKS, profile
HERE=Path(__file__).resolve().parent
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else HERE/'textures'
OUT.mkdir(parents=True,exist_ok=True)
def source(name):
    return np.asarray(Image.open(HERE.parent/'art'/name).convert('RGB'),dtype=float)
turn=source('nagi-turnaround.png')
team=source('racers.png')
ratio=turn.shape[1]/1250
def cleaned(im,box,poly=None,redbox=None):
    x0,y0,x1,y1=(int(v*ratio) for v in box)
    img=im[y0:y1,x0:x1].copy()
    r,g,b=img.transpose(2,0,1)
    bg=(r>222)&(g>207)&(b>187)&(r-g<37)&(g-b<28)
    from scipy.ndimage import binary_fill_holes
    valid=binary_fill_holes(~bg)
    if poly:
        mask=Image.new('L',(x1-x0,y1-y0))
        ImageDraw.Draw(mask).polygon([(x*ratio-x0,y*ratio-y0) for x,y in poly],fill=255)
        valid &= np.asarray(mask)>0
        # Warm cream hair can be close to the paper. Retain enclosed highlights.
        from scipy.ndimage import binary_fill_holes
        valid=binary_fill_holes(valid)
    if redbox:
        yy,xx=np.indices(valid.shape)
        a,b0,c,d=redbox
        accessory=(xx+x0>=a*ratio)&(xx+x0<c*ratio)&(yy+y0>b0*ratio)&(yy+y0<d*ratio)&(r>1.22*b)&(r>g*1.38)
        valid &= ~accessory
    idx=distance_transform_edt(~valid,return_distances=False,return_indices=True)
    return img[tuple(idx)],x0,y0
def sample(info,x,y):
    im,x0,y0=info
    return np.stack([map_coordinates(im[:,:,j],np.array([y*ratio-y0,x*ratio-x0]),order=1,mode='nearest') for j in range(3)],axis=-1)
front=cleaned(turn,(155,15,387,201),None,(311,0,390,137))
side=cleaned(turn,(524,14,735,201),None,(597,0,686,134))
back=cleaned(turn,(863,16,1091,201),None,(860,0,942,130))
def rgb(v):return tuple(ImageColor.getrgb(v))
def smooth(a,b,x):
    f=np.clip((x-a)/(b-a),0,1)
    return f*f*(3-2*f)
for i,c in enumerate(CAST):
    th,v=np.meshgrid(np.linspace(-np.pi,np.pi,1024),np.linspace(0,1,512))
    xyz=np.array([profile(c,a,b) for a,b in zip(th.flat,v.flat)]).reshape(512,1024,3)
    x,y,z=xyz.transpose(2,0,1)
    sy=c['floor']-z/c['k']
    af=np.abs(th)
    src=front if i==0 else cleaned(team,(c['cx']-111,c['stations'][0][0]-2,c['cx']+111,c['stations'][-1][0]+2),FRONT_MASKS[i])
    col=sample(src,c['cx']+x/c['k'],sy)
    if i==0:
        # Restore the bob underneath the separately articulated bow. Its opposite
        # temple is fully visible in the frontal sheet; use that symmetrical weave.
        mirror=sample(front,c['cx']-x,sy)
        repair=(smooth(34,48,x)*(1-smooth(115,148,sy)))[:,:,None]
        col=col*(1-repair)+mirror*repair
        bx=977-x
        rear=sample(back,977+np.abs(bx-977),sy)
        sx=603+y
        sidecol=sample(side,sx,sy)
        # The front artwork already supplies both eyes. Only project the temporal
        # hair/ear from the profile, and restore the near-side bow occlusion using
        # the unobstructed back locks.
        sidehair=sample(back,1001+np.clip(sx-620,-17,64),sy)
        restore=(1-smooth(675,697,sx))*(1-smooth(127,149,sy))
        sidecol=sidecol*(1-restore[:,:,None])+sidehair*restore[:,:,None]
        w=smooth(1.09,1.53,af)[:,:,None]
        # The cheek is visible in profile between the bangs and the side lock.
        # Retain the front eyes, then blend into the actual ear and profile eye.
        cheek=smooth(115,138,sy)[:,:,None]
        w=w*(1-cheek)+smooth(.59,1.06,af)[:,:,None]*cheek
        # The ear lies behind the cheek locks. Reserve its projection for the
        # side-on part of the mesh where it cannot bleed across the frontal bob.
        ear_region=(smooth(596,609,sx)*smooth(129,143,sy)*(1-smooth(187,198,sy)))[:,:,None]
        w*=1-ear_region*(1-smooth(1.26,1.51,af)[:,:,None])
        col=col*(1-w)+sidecol*w
        w=smooth(1.79,2.42,af)[:,:,None]
    else:
        # Rivals have no reverse sheet. Recolour the lock relief of the supplied bob.
        ny=21+177*v
        rx=977-np.sin(th)*np.array([profile(CAST[0],np.pi/2,float(t))[0] for t in v[:,0]])[:,None]
        rear=sample(back,rx,ny)
        lum=(rear@np.array([.22,.59,.19]))
        shade=np.clip((lum-45)*1.3,-49,60)
        rear=np.clip(np.array(rgb(c['hair']))+shade[:,:,None],0,255)
        w=smooth(.88,1.83,af)[:,:,None]
    out=np.clip(col*(1-w)+rear*w,0,255).astype(np.uint8)
    atlas=Image.new('RGB',(1024,1024))
    atlas.paste(Image.fromarray(out),(0,0))
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
    # Two small opaque eyelid patches use the colour of the individual cheek.
    for j,(ex,ey,ew,eh) in enumerate(EYES[i]):
        g=ImageDraw.Draw(atlas)
        x0=300+j*160;y0=640
        # Start with the exact open-eye projection. Feather skin only around the
        # iris and lashes so the animated lids carry no rectangular colour border.
        uu,vv=np.meshgrid(np.linspace(-1,1,140),np.linspace(-1,1,100))
        px=ex+uu*ew*1.30;py=ey+vv*eh*1.275
        normalized=(py-c['stations'][0][0])/(c['stations'][-1][0]-c['stations'][0][0])
        sy_patch=py-(7-2*np.cos((px-c['cx'])/80*13))*normalized**5/c['k']
        base=sample(src,px,sy_patch)
        cheek=sample(src,px,ey+eh*1.14+vv*eh*.10)
        base_skin=np.array(rgb(c['skin']))
        skin=.68*base_skin+.32*cheek
        # Closed lids keep the brow and corner of the natural eye.
        blend=(1-smooth(.77,1.01,abs(uu)))*(1-smooth(.74,1.0,abs(vv)))
        patch=base*(1-blend[:,:,None])+skin*blend[:,:,None]
        atlas.paste(Image.fromarray(np.uint8(np.clip(patch,0,255))),(x0,y0))
        pts=[(x0+x,y0+50-12*np.sin(np.pi*x/139)+(3 if j else -3)*(x/139-.5)) for x in range(8,135)]
        g.line(pts,fill='#513039',width=7,joint='curve')
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
    hu,hv=np.meshgrid(np.linspace(0,1,150),np.linspace(0,1,230))
    strand=np.array(rgb(c['hair']))+((10*np.cos(hu*2*np.pi)+7*np.sin(hu*2*np.pi*3+hv*4)+3*np.cos(hu*2*np.pi*7+hv*3)+10*np.sin(hv*np.pi)-8)[:,:,None])
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
