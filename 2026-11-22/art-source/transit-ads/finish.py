"""Compose original MOSS plates, then set Japanese display and merchant copy. No metal frame or surround."""
from pathlib import Path
import json,hashlib,sys
from PIL import Image,ImageDraw,ImageFont,ImageOps
import numpy as np
root=Path(__file__).resolve().parent
out=Path(sys.argv[1]);out.mkdir(exist_ok=True,parents=True)
plates=[
 ('needle','針音堂','レコード針','交換針、あります。','針先の相談はカウンターへ。',(243,223,177),(65,42,34),(158,57,45),0),
 ('phone','共同送像所','テレビ電話','顔を見て、話そう。','遠くの家族と、町の送像所で。',(211,225,212),(32,60,63),(38,104,92),1),
 ('lotus','純喫茶 ロータス','朝の珈琲','一杯ずつ、サイフォンで。','開店の香りを、いつもの席で。',(245,227,197),(75,48,37),(132,66,42),0),
 ('trumpet','キャバレー 金星','公開録音','遠来の吹き手','出演のご案内は金星の帳場へ。',(219,217,193),(40,44,57),(104,63,58),1)]
def typeface(n,serif=False):
 return ImageFont.truetype('C:/Windows/Fonts/'+('msmincho.ttc' if serif else 'meiryo.ttc'),n)
def setline(d,x,y,s,font_size,color,serif=False,width=518):
 while d.textlength(s,font=typeface(font_size,serif))>width:font_size-=1
 d.text((x,y),s,fill=color,font=typeface(font_size,serif),anchor='lm')
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
canvas=Image.new('RGB',(2048,800));catalog=[]
for i,(key,merchant,head,deck,sub,bg,ink,accent,reverse) in enumerate(plates):
 f=root/'originals'/(key+'.png')
 rng=np.random.default_rng(i+2069)
 img=Image.fromarray(np.uint8(np.clip(np.array(bg)+rng.normal(0,1.75,(400,1024,1)),0,255)))
 art=ImageOps.fit(Image.open(f).convert('RGB'),(455,400),method=Image.Resampling.LANCZOS)
 img.paste(art,(569 if reverse else 0,0));d=ImageDraw.Draw(img)
 x=28 if reverse else 483
 setline(d,x,57,merchant,32,accent,True)
 d.line((x,92,x+509,92),fill=accent,width=3)
 setline(d,x,157,head,76,ink,True)
 setline(d,x,247,deck,43,ink,True)
 d.line((x,298,x+80,298),fill=accent,width=2)
 setline(d,x,345,sub,26,ink)
 canvas.paste(img,(1024*(i%2),400*(i//2)))
 rec=json.loads((root/'originals'/(key+'.json')).read_text());assert rec['sha256']==sha(f)
 rec.update(accepted=True,merchant=merchant,head=head,deck=deck,sub=sub,uv=[.5*(i%2),.5*(1-i//2),.5,.5])
 catalog.append(rec)
atlas=out/'CarAdvertisements.png';canvas.save(atlas,optimize=True)
canvas.thumbnail((1440,563));canvas.save(root/'index.jpg',quality=93,subsampling=0)
(root/'catalog.json').write_text(json.dumps(dict(model='MOSS-Image',atlas_sha256=sha(atlas),plates=catalog),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
