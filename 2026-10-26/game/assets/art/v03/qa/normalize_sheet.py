from pathlib import Path
from PIL import Image,ImageDraw
import json,sys
root=Path(__file__).resolve().parents[1]
name,source=sys.argv[1:]
im=Image.open(source).convert('RGBA'); w,h=im.size
names=[['down_left','up_left','side_left'],['down_right','up_right','side_right']]
# Locate opaque connected silhouettes first; generated poses may cross nominal grid midpoints.
a=bytearray(im.getchannel('A').tobytes());components=[]
for i in range(w*h):
 if a[i]<=32:continue
 stack=[i];a[i]=0;minx=w;maxx=0;miny=h;maxy=0;n=0
 while stack:
  j=stack.pop();x=j%w;y=j//w;n+=1;minx=min(minx,x);maxx=max(maxx,x);miny=min(miny,y);maxy=max(maxy,y)
  for k in (j-1 if x else -1,j+1 if x<w-1 else -1,j-w,j+w):
   if 0<=k<w*h and a[k]>32:a[k]=0;stack.append(k)
 if n>10000:components.append((minx,miny,maxx+1,maxy+1))
isolation_note='six isolated connected source silhouettes'
if len(components)!=6:raise ValueError(f'Expected six silhouettes, got {len(components)}')
records=[]; thumbs=[]
for row in range(2):
 for col in range(3):
  slot=(col*w//3,row*h//2,(col+1)*w//3,(row+1)*h//2)
  candidates=[b for b in components if col*w//3 <= (b[0]+b[2])/2 < (col+1)*w//3 and row*h//2 <= (b[1]+b[3])/2 < (row+1)*h//2]
  if len(candidates)!=1:raise ValueError('Ambiguous slot components')
  bbox=candidates[0]
  if bbox is None:raise ValueError('Empty sprite')
  # Alpha threshold locates bounds only; source antialias and RGB pixels are preserved.
  crop=im.crop(bbox);scale=288/crop.height
  size=(round(crop.width*scale),288)
  if size[0]>312:raise ValueError('Sprite too wide')
  crop=crop.resize(size,Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(320,320));at=((320-size[0])//2,304-size[1]);canvas.alpha_composite(crop,at)
  dest=root/'crew'/f'{name}_{names[row][col]}.png';canvas.save(dest)
  records.append({'pose':names[row][col],'file':str(dest.relative_to(root)),'sourceSlot':slot,'sourceVisibleBounds':bbox,'canvas':[320,320],'visibleHeight':288,'footOrigin':[160,304]})
  thumb=canvas.resize((104,104),Image.Resampling.LANCZOS);thumbs.append(thumb)
# Preview source art at exactly94px visible character height over the actual R2 stone texture.
terrain=Image.open(root.parents[3]/'game/assets/art/r2/terrain-day.png').convert('RGB')
terrain=terrain.crop((0,0,terrain.width//2,terrain.height//2)).resize((64,64))
sheet=Image.new('RGB',(600,290),'#f9f1da')
for i,thumb in enumerate(thumbs):
 x=(i%3)*200;y=(i//3)*145
 for ty in range(y,y+128,64):
  for tx in range(x,x+192,64):sheet.paste(terrain,(tx,ty))
 sheet.paste(thumb,(x+58,y+9),thumb)
 ImageDraw.Draw(sheet).text((x+8,y+128),records[i]['pose']+' / 94px',fill='#183e52')
sheet.save(root/'qa'/f'{name}-94px-source-preview.png')
alpha=im.getchannel('A');counts=alpha.histogram();report={'name':name,'source':source,'dimensions':im.size,'mode':im.mode,'alphaZeroFraction':counts[0]/(w*h),'alphaMax':alpha.getextrema()[1],'isolationNote':isolation_note,'poses':records,'status':'source QA only; not an in-game motion validation'}
(root/'qa'/f'{name}-report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
