"""Typeset the pass and costume card, and make the 3D surfaces and artwork index."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = Path(__file__).resolve().parent
NAMES = ["戸の張地","楽屋の通し札","専属歌手の写真","衣裳部の札","雨上がりの路地","引手の手擦れ","楽屋の暮らし","戸が開く瞬間"]
def lettering(image, size, at, text, ink, fonts, face="yumindb.ttf", anchor="mm"):
    ImageDraw.Draw(image).text(at,text,font=ImageFont.truetype(str(fonts/face),size),fill=ink,anchor=anchor)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("work",type=Path)
    parser.add_argument("--fonts",type=Path,default=Path("C:/Windows/Fonts"))
    args=parser.parse_args()
    output=HERE.parent.parent/"Game"/"Assets"/"Resources"/"KinseiBackstage"
    output.mkdir(parents=True,exist_ok=True)
    concepts=HERE/"studies"
    concepts.mkdir(exist_ok=True)
    proof=Image.new("RGB",(1408,620),"#e7ddc9")
    records=[]
    for i,plate in enumerate(json.loads((HERE/"plates.json").read_text(encoding="utf8"))):
        key=plate["key"]
        raw=args.work/(key+".png")
        record=json.loads(raw.with_suffix(".json").read_text(encoding="utf8"))
        assert record["sha256"]==hashlib.sha256(raw.read_bytes()).hexdigest()
        records.append(record)
        with Image.open(raw) as opened:
            image=opened.convert("RGB")
        assert image.size==(plate["width"],plate["height"])
        if key=="hall-pass":
            # Artwork is printed on a physical 210 x 120 mm card.
            image=image.resize((1260,720), Image.Resampling.LANCZOS)
            ink=(230,208,152)
            lettering(image,120,(712,312),"楽 屋 通 し 札",ink,args.fonts)
            lettering(image,42,(713,448),"金 星 興 行 部　／　宵 待 町",ink,args.fonts)
            lettering(image,26,(715,534),"第 二 五 番　・　返 却 用",ink,args.fonts)
        if key=="wardrobe-card":
            image=image.resize((1152,720),Image.Resampling.LANCZOS)
            ink=(82,47,49)
            lettering(image,74,(520,196),"金 星　衣 裳 部",ink,args.fonts)
            lettering(image,48,(135,438),"夜の椿　舞台衣裳",ink,args.fonts,anchor="lm")
            lettering(image,40,(135,534),"深葡萄　金糸二本",ink,args.fonts,anchor="lm")
        if plate["resource"]:
            image.save(output/(plate["resource"]+".png"),optimize=True)
        else:
            image.save(concepts/(key+".jpg"),quality=94,subsampling=0)
        thumb=ImageOps.contain(image,(326,228),Image.Resampling.LANCZOS)
        x=i%4*352; y=i//4*310
        proof.paste(thumb,(x+(352-thumb.width)//2,y+18+(228-thumb.height)//2))
        lettering(proof,27,(x+176,y+273),NAMES[i],(59,42,40),args.fonts)
    proof.save(HERE/"index.jpg",quality=92)
    (HERE/"runs.json").write_text(json.dumps(records,indent=2)+"\n",encoding="utf8")

if __name__=="__main__":
    main()
