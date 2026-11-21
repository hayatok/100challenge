"""Prepare the route enamel, moquette repeat and Edmondson fare sample for Unity."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE=Path(__file__).resolve().parent
NAMES=["宵待高架線の路線札","長椅子のモケット","硬券見本","夜の客室","昇降機とホーム"]
def wrap_pile(image):
    # Mirror a narrow edge neighbourhood onto its opposite side and taper the blend in linear light.
    pixels=np.asarray(image,dtype=float)/255
    linear=np.where(pixels<=.04045,pixels/12.92,((pixels+.055)/1.055)**2.4)
    for axis in (0,1):
        array=linear.swapaxes(0,axis)
        width=32
        left=array[:width].copy()
        right=array[-width:][::-1].copy()
        t=np.linspace(1,0,width).reshape(-1,1,1)
        w=.5*t*t*(3-2*t)
        array[:width]=left*(1-w)+right*w
        array[-width:]=(right*(1-w)+left*w)[::-1]
    rgb=np.where(linear<=.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)
    return Image.fromarray(np.rint(255*np.clip(rgb,0,1)).astype("uint8"))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("work",type=Path)
    ap.add_argument("--out",type=Path,default=HERE.parent.parent/"Game"/"Assets"/"Resources"/"KinseiRail")
    ap.add_argument("--fonts",type=Path,default=Path("C:/Windows/Fonts"))
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    (HERE/"studies").mkdir(exist_ok=True)
    sheet=Image.new("RGB",(1440,650),"#eae2ce")
    def text(im,xy,caption,points,fill,font="yumindb.ttf"):
        ImageDraw.Draw(im).text(xy,caption,font=ImageFont.truetype(str(args.fonts/font),points),fill=fill,anchor="mm")
    runs=[]
    for i,plate in enumerate(json.loads((HERE/"plates.json").read_text(encoding="utf8"))):
        k=plate["key"];path=args.work/(k+".png")
        record=json.loads(path.with_suffix(".json").read_text(encoding="utf8"))
        assert record["sha256"]==hashlib.sha256(path.read_bytes()).hexdigest()
        runs.append(record)
        with Image.open(path) as original:
            image=original.convert("RGB")
        assert image.size==(plate["width"],plate["height"])
        if k=="route-board":
            image=image.resize((2160,460),Image.Resampling.LANCZOS)
            ink="#3f3530";red="#843a3e";mark=ImageDraw.Draw(image)
            text(image,(1080,115),"宵 待 高 架 線",56,red)
            mark.line([(500,239),(1660,239)],fill=red,width=12)
            for x in (500,1660):
                mark.ellipse((x-21,218,x+21,260),fill="#f1e9d2",outline=red,width=9)
            text(image,(500,330),"宵 待 西 口",63,ink)
            text(image,(1660,330),"送 像 所 前",63,ink)
        elif k=="moquette":
            image=wrap_pile(image)
        elif k=="fare-ticket":
            image=image.resize((1200,600),Image.Resampling.LANCZOS)
            ink="#352d2c"
            text(image,(610,132),"宵待高架線　乗車券",61,ink)
            text(image,(612,292),"宵待西口　→　送像所前",77,ink)
            text(image,(556,444),"昭和一〇一年　当日限り",46,ink)
            text(image,(979,502),"0831",34,"#922f32","YuGothB.ttc")
        if plate["resource"]:
            image.save(args.out/(plate["resource"]+".png"),optimize=True)
        else:
            image.save(HERE/"studies"/(k+".jpg"),quality=94,subsampling=0)
        x=(i if i<3 else i-3)*480+(240 if i>=3 else 0);y=0 if i<3 else 325
        thumb=ImageOps.contain(image,(442,245),Image.Resampling.LANCZOS)
        sheet.paste(thumb,(x+(480-thumb.width)//2,y+15+(245-thumb.height)//2))
        text(sheet,(x+240,y+285),NAMES[i],29,"#483d34")
    sheet.save(HERE/"index.jpg",quality=91)
    (HERE/"runs.json").write_text(json.dumps(runs,indent=2)+"\n",encoding="utf8")

if __name__=="__main__":
    main()
