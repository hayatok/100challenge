"""Draw original CRT service signals in the existing NightGeometry 2x2 pane UV layout."""
from PIL import Image,ImageDraw
import math,sys
from pathlib import Path
side=320; sheet=Image.new('RGB',(2*side,2*side))
for k in range(4):
    tile=Image.new('RGB',(side,side),(13,28,27));d=ImageDraw.Draw(tile)
    for t in range(30,300,26):
        d.line((t,31,t,289),fill=(41,62,56));d.line((30,t,289,t),fill=(41,62,56))
    if k==0:
        pts=[(x,round(158-62*math.sin((x-24)*math.pi/57))) for x in range(30,291)]
        d.line(pts,fill=(193,220,172),width=5)
    elif k==1:
        d.ellipse((49,50,271,272),outline=(152,166,151),width=5)
        for i in range(7):
            v=210-i*25;d.rectangle((55+i*30,135,84+i*30,177),fill=(v,int(.95*v),int(.82*v)))
    elif k==2:
        for i in range(5):
            d.line((33+i*51,216-i*29,83+i*51,216-i*29),fill=(161,194,150),width=5)
            if i<4:d.line((83+i*51,216-i*29,83+i*51,187-i*29),fill=(161,194,150),width=4)
    sheet.paste(tile,(k%2*side,k//2*side))
sheet.save(Path(sys.argv[1])/'BenchPatterns.png')
