"""Assemble existing renders and references; no model edits."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
base=Path(__file__).resolve().parent.parent
previews=base/'previews'
views=['front','left','right','back','threequarter']
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',20)
small=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',15)

def caption(image,text):
    draw=ImageDraw.Draw(image);draw.rectangle((0,0,image.width,34),fill='#142c3e');draw.text((9,6),text,font=font,fill='white')
    return image
sheet=Image.new('RGB',(5*320,3*480),'#fffdf8')
for row,key in enumerate(['old','new']):
    for column,view in enumerate(views):
        image=Image.open(previews/f'{key}_{view}.png').convert('RGB').resize((320,480))
        caption(image,f'{key.upper()} / {view}')
        sheet.paste(image,(column*320,row*480))
for column,view in enumerate(views[:4]):
    image=Image.open(base/f'ref/{view}.png').convert('RGB')
    pixels=image.load();ys=[]
    for y in range(image.height):
        dark=sum(1 for x in range(image.width) if min(pixels[x,y])<145)
        if dark>5:ys.append(y)
    crop=image.crop((0,min(ys),image.width,max(ys)+1))
    crop=crop.resize((round(crop.width*420/crop.height),420))
    frame=Image.new('RGB',(320,480),'#fffdf8');frame.paste(crop,((320-crop.width)//2,30));caption(frame,f'REF / {view}')
    sheet.paste(frame,(column*320,960))
ImageDraw.Draw(sheet).text((1290,1005),'All bodies have the\nsame displayed height.\n\nReference poses differ\nslightly in the arms.\n\nRender material and\ngeometry are unmodified.',font=small,fill='#142c3e',spacing=10)
sheet.save(previews/'fullbody-comparison.png')
face=Image.new('RGB',(5*384,2*384),'#142c3e')
for row,key in enumerate(['old','new']):
    for column,view in enumerate(['front','left','right','back','threequarter']):
        image=Image.open(previews/f'{key}_face_{view}.png').convert('RGB').resize((384,384))
        caption(image,f'{key.upper()} / {view}')
        face.paste(image,(column*384,row*384))
face.save(previews/'face-comparison.png')
print('COMPARISON_BOARDS_SAVED')
