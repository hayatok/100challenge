"""Original paper ephemera and atmospheric surround; Pillow, numpy, Windows fonts."""
from pathlib import Path
import sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(196911)
def font(size,mincho=False):
    return ImageFont.truetype('C:/Windows/Fonts/'+('msmincho.ttc' if mincho else 'meiryo.ttc'),size)
def card(caption,main,sub,number,ink,base):
    noise=rng.normal(0,2.3,(384,640,1))+rng.normal(0,1.1,(384,1,1))
    im=Image.fromarray(np.uint8(np.clip(np.array(base)+noise,0,255)))
    d=ImageDraw.Draw(im);d.rectangle((13,12,626,370),outline=ink,width=3)
    d.text((35,31),caption,fill=ink,font=font(31))
    d.text((604,50),number,fill=ink,font=font(26),anchor='rm')
    d.line((35,90,605,90),fill=ink,width=3)
    d.text((320,186),main,fill=ink,font=font(min(83,530//max(len(main),1)),True),anchor='mm')
    d.line((68,262,572,262),fill=ink,width=1)
    d.text((320,310),sub,fill=ink,font=font(min(34,545//max(1,len(sub)))),anchor='mm')
    return im
def atlas(name,records,ink,base):
    im=Image.new('RGB',(1280,768))
    for j,record in enumerate(records):im.paste(card(*record,ink,base),(j%2*640,j//2*384))
    im.save(out/(name+'.jpg'),quality=95,subsampling=0)
atlas('RelayPaper',[
 ('純喫茶 ロータス','朝のリクエスト','お好きな曲を一曲、どうぞ','受付'),
 ('純喫茶 ロータス','堺の朝','共同送像所　御中','依頼票'),
 ('共同送像所','朝番組　準備中','宵待町共同放送','運行表'),
 ('共同送像所','放送中','演奏中　堺の朝','番組札')],(36,72,59),(225,220,187))
atlas('OfficePaper',[
 ('キャバレー 金星','帳場受付','本日の前売りは針音堂へ','興行部'),
 ('貸レコード 針音堂','前売り準備中','開演時刻は店頭でご案内します','窓口'),
 ('貸レコード 針音堂','前売り受付','金星興行　一番券到着','窓口'),
 ('純喫茶 ロータス','朝の仕込み','コーヒーをいれています','開店前')],(100,46,44),(232,216,181))
crt=Image.new('RGB',(512,384),(36,57,56));d=ImageDraw.Draw(crt)
for i in range(8):d.rectangle((56+i*50,50,105+i*50,69),fill=(85+i*13,96+i*13,91+i*12))
d.ellipse((102,70,409,348),outline=(121,145,129),width=2)
for y,t,size in [(118,'宵待町共同放送',28),(200,'堺の朝',64),(285,'純喫茶ロータスから',22)]:
    d.text((256,y),t,font=font(size,True),anchor='mm',fill=(217,229,207))
arr=np.asarray(crt).copy();arr[::3]=(arr[::3]*.90).astype(np.uint8);Image.fromarray(arr).save(out/'MorningSignal.png')
# Match the existing dome UV: elevation=0 at the horizon, +pi/2 at zenith.
w,h=1024,256; az=np.arange(w)*2*np.pi/w;el=np.linspace(np.pi/2,0,h)[:,None];v=np.sin(el)
horizon=np.array([208.,179.,157.]);zenith=np.array([74.,119.,154.])
base=(horizon+(zenith-horizon)*(np.sqrt(v)[:,:,None]))+np.zeros((h,w,3))
dot=np.cos(el)*np.cos(.32)*np.cos(az-1.06)+np.sin(el)*np.sin(.32)
base+=np.exp(-(1-dot)*7)[:,:,None]*np.array([42,28,12])
for k in range(3):
    band=.08+.055*k+.017*np.sin(3*az+k)+.013*np.cos(5*az+.9*k)
    veil=np.exp(-((el-band)/(.021+.005*k))**2)*(.54+.35*np.sin(2*az+k))
    base+=veil[:,:,None]*np.array([15,15,13])
disc=np.clip((dot-np.cos(.012))/.000048,0,1)
base=base*(1-disc[:,:,None])+np.array([255,246,209])*disc[:,:,None]
Image.fromarray(np.uint8(np.clip(base+rng.normal(0,.45,(h,w,1)),0,255))).save(out/'MorningAir.jpg',quality=93)
