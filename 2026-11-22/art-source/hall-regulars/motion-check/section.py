"""Draw the final right trouser/hand section from the Unity probe's binary mesh dump."""
from argparse import ArgumentParser
from pathlib import Path
import struct
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ap=ArgumentParser(description=__doc__)
ap.add_argument('mesh',type=Path)
ap.add_argument('png',type=Path)
args=ap.parse_args()
with args.mesh.open('rb') as stream:
    hand_count,cloth_count,index_count=struct.unpack('<3i',stream.read(12))
    def read_rows(count,dtype):
        return np.frombuffer(stream.read(count*12),dtype).reshape(-1,3)
    hand=read_rows(hand_count,'<f4')
    cloth=read_rows(cloth_count,'<f4')
    triangles=read_rows(index_count//3,'<i4')
    assert not stream.read(1)
# These faces were filtered by the dominant right hip/knee bone in the Unity probe.
plane=.081
segments=[]
for vertices in cloth[triangles]:
    crossings=[]
    for a,b in zip(vertices,np.roll(vertices,-1,axis=0)):
        if (a[0]-plane)*(b[0]-plane)<0:
            crossings.append(a+(b-a)*((plane-a[0])/(b[0]-a[0])))
    if len(crossings)==2:
        segments.append(crossings)
hand=hand[np.abs(hand[:,0]-plane)<=.002]
ink='#263c50'
skin='#bc6c40'
paper='#f1ece3'
font=ImageFont.load_default(size=20)
out=Image.new('RGB',(1200,545),paper)
for i,(title,ycentre,zcentre,scale,length) in enumerate([
    ('Right leg and hand',.369,.31,1500,.050),
    ('Heel of palm and upper trouser',.473,.377,3750,.020)
]):
    panel=Image.new('RGB',(600,460),paper)
    draw=ImageDraw.Draw(panel)
    def xy(p):
        return (300+(p[2]-zcentre)*scale,230-(p[1]-ycentre)*scale)
    for a,b in segments:
        draw.line([xy(a),xy(b)],fill=ink,width=3)
    for p in hand:
        x,y=xy(p)
        draw.ellipse((x-1.3,y-1.3,x+1.3,y+1.3),fill=skin)
    out.paste(panel,(600*i,45))
    draw=ImageDraw.Draw(out);draw.text((600*i+25,11),title,fill=ink,font=font)
    draw.rectangle((600*i+20,446,600*i+180,495),fill=paper)
    draw.line((600*i+25,457,600*i+25+length*scale,457),fill=ink,width=3)
    draw.text((600*i+25,465),f'{int(length*1000)} mm',fill=ink,font=font)
draw=ImageDraw.Draw(out)
draw.text((24,508),'x = 81 mm     Navy: right trouser section     Orange: hand vertices within 2 mm of the section',fill=ink,font=font)
out.save(args.png)
