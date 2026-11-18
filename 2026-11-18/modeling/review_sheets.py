"""Compose the reference and reimport renders on readable, equal-height sheets."""
import json,sys
from pathlib import Path
import numpy as np
from scipy.ndimage import binary_fill_holes,label
from PIL import Image,ImageDraw,ImageFont,ImageOps
HERE=Path(__file__).resolve().parent
art=HERE.parent/'art';out=HERE/'review';render=Path(sys.argv[1]); out.mkdir(exist_ok=True)
cream='#fcf2e8';blue='#26324b';font=ImageFont.load_default(size=17);small=ImageFont.load_default(size=13)
def bg(im):
    flat=Image.new('RGBA',im.size,cream);flat.alpha_composite(im.convert('RGBA'));return flat.convert('RGB')
def fit(im,size):
    cell=Image.new('RGB',size,cream)
    item=ImageOps.contain(bg(im),size);cell.paste(item,((size[0]-item.width)//2,(size[1]-item.height)//2));return cell
def label_text(sheet,x,y,title):
    ImageDraw.Draw(sheet).text((x,y),title,font=font,fill=blue)
def source(name):
    return Image.open(art/name).convert('RGB')
ref=source('nagi-turnaround.png').resize((1250,417),Image.Resampling.LANCZOS)
panel=Image.new('RGB',(1100,660),cream)
g=ImageDraw.Draw(panel)
mask_scores={}
for n,(name,cx,lo,hi) in enumerate([('front',273,150,390),('side',603,515,740),('rear',977,853,1093)]):
    crop=ref.crop((lo,8,hi,400))
    img=Image.open(render/(name+'.png')).convert('RGBA')
    alpha=np.asarray(img.getchannel('A'))>127
    # Label-free product sheet with warm paper; restrict drop shadow at the sole line.
    pix=np.asarray(crop,dtype=float);dist=np.linalg.norm(pix-np.array([253,242,233]),axis=2)
    m=binary_fill_holes(dist>49);tags,nm=label(m); m=tags==(1+np.argmax(np.bincount(tags.flat)[1:]))
    # Register each matte to the sole centre at the same px/m. The side view has
    # a different reference offset; its sole centre is x=598, torso centre x=603.
    ys,xs=np.where(m);cropbox=(xs.min(),ys.min(),xs.max()+1,ys.max()+1)
    rr=Image.fromarray((m*255).astype('uint8')).crop(cropbox)
    ys,xs=np.where(alpha);aa=Image.fromarray((alpha*255).astype('uint8')).crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
    w=round(aa.width*rr.height/aa.height)
    aa=aa.resize((w,rr.height),Image.Resampling.NEAREST)
    width=max(aa.width,rr.width)
    def center(m):
        ims=Image.new('L',(width,m.height));ims.paste(m,((width-m.width)//2,0));return np.asarray(ims)>127
    m1,m2=center(rr),center(aa)
    mask_scores[name]=round(float((m1&m2).sum()/(m1|m2).sum()),3)
    x0=12+n*363
    label_text(panel,x0+7,8,name.upper())
    panel.paste(fit(crop,(340,284)),(x0,38))
    renderbox=img.getbbox()
    panel.paste(fit(img.crop(renderbox),(340,284)),(x0,354))
g.line((10,329,1090,329),fill='#d8c8b9',width=1)
g.text((13,332),'EXPORTED GLB  /  ORTHOGRAPHIC',font=small,fill=blue)
panel.save(out/'nagi-turnaround.webp',quality=90)
face_sheet=Image.new('RGB',(1324,330),cream)
for column,(name,im) in enumerate((('DRAWING',ref.crop((150,11,390,202))),
        ('EXPORTED GLB  /  FRONT',Image.open(render/'face-front.png')),
        ('ELEVATED 23 DEGREES',Image.open(render/'face-raised.png')),
        ('THREE-QUARTER',Image.open(render/'face-quarter.png')))):
    label_text(face_sheet,10+330*column,8,name)
    face_sheet.paste(fit(im,(320,275)),(5+330*column,40))
face_sheet.save(out/'nagi-face.webp',quality=93)
team=Image.new('RGB',(1390,1392),cream)
for y,title,im in [(0,'REFERENCE  /  CAST SHEET',source('racers.png')),(342,'EXPORTED GLBS  /  FRONT',Image.open(render/'cast-front.png')),(692,'EXPORTED GLBS  /  THREE-QUARTER',Image.open(render/'cast-quarter.png')),(1040,'EXPORTED GLBS  /  REAR',Image.open(render/'cast-rear.png'))]:
    label_text(team,16,y+4,title)
    if y==0:im=im.crop((0,25,im.width,690))
    im=fit(im,(1372,315));team.paste(im,(9,y+28))
team.save(out/'cast.webp',quality=89)
motion=Image.new('RGB',(1200,715),cream)
label_text(motion,16,7,'REFERENCE  /  NAGI JUMP')
motion.paste(fit(source('nagi-jump.png'),(1200,296)),(0,30))
label_text(motion,16,341,'EXPORTED GLB  /  SKELETON POSES')
for j,n in enumerate(['idle','jump','land','run','stumble','finish']):
    im=Image.open(render/(n+'.png'));rim=im.crop(im.getbbox())
    motion.paste(fit(rim,(190,293)),(j*200+5,371))
    ImageDraw.Draw(motion).text((j*200+14,675),n.upper(),font=small,fill=blue)
motion.save(out/'motion.webp',quality=90)

# Each angle shares the same camera, framing and ground plane across all six
# samples; no per-pose cropping or resizing can disguise the change in height.
strip=Image.new('RGB',(1324,486),cream)
draw=ImageDraw.Draw(strip)
for j,name in enumerate(['Left support','Right support','Reach','Forearms','Belly slide','Foot plant']):
    x=8+218*j
    draw.text((x+4,7),name,font=font,fill=blue)
    for y,view in [(53,'profile'),(278,'chase')]:
        img=bg(Image.open(render/f'{view}-{j}.png'))
        strip.paste(img.resize((214,195),Image.Resampling.LANCZOS),(x,y))
draw.text((12,33),'NAGI  /  GLB PROFILE',font=small,fill=blue)
draw.line((9,251,1315,251),fill='#d8c8b9')
draw.text((12,257),'REAR THREE-QUARTER',font=small,fill=blue)
strip.save(out/'sport-motion.webp',quality=88)
performance=Image.new('RGB',(1272,902),cream)
for r,(clip,title) in enumerate((('ready','PRE-RACE'),('launch','FIRST PUSH'),('finish','FINISH'),('finish_win','WIN'))):
    y=224*r
    label_text(performance,10,y+4,title)
    for i in range(6):
        frame=bg(Image.open(render/f'performance-{i}-{clip}.png'))
        performance.paste(frame.resize((198,198),Image.Resampling.LANCZOS),(9+210*i,y+24))
performance.save(out/'performance.webp',quality=90)
(out/'silhouette.json').write_text(json.dumps({'alignment':'bounding-box height and horizontal centre, neutral poses','iou':mask_scores},indent=2)+'\n')
