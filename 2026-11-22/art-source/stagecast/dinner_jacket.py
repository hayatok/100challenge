"""Use the casting wardrobe's existing single-breasted UVs to make the club tuxedo."""
import sys,struct
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np
src,out=map(Path,sys.argv[1:]); data=(src/'Single.bytes').read_bytes();n,indices=struct.unpack_from('<ii',data)
buffer=np.ndarray((n,8),dtype='<f4',buffer=data,offset=8,strides=(52,4))
faces=np.frombuffer(data,dtype='<u2',count=indices,offset=8+n*52).reshape(-1,3)
cream=Image.open(src/'Cream.jpg').convert('RGB'); pigment=np.asarray(cream).copy()
mask=Image.new('L',cream.size);pen=ImageDraw.Draw(mask)
for f in faces:
 p=buffer[f]
 if p[:,1].max()<.964:
    pen.polygon([(u*cream.width,(1-v)*cream.height) for u,v in p[:,6:8]],fill=255)
navy=np.asarray(Image.open(src/'Navy.jpg').convert('RGB'))
color=np.asarray(cream)
red=(color[:,:,0].astype(float)>color[:,:,1].astype(float)*1.55)&(color[:,:,1]<95)
pigment[red]=np.uint8(np.clip(color[red]*np.array([.33,.56,.63]),0,255))
Image.composite(Image.fromarray(navy),Image.fromarray(pigment),mask.filter(ImageFilter.MaxFilter(5))).save(out/'DinnerJacket.jpg',quality=93,subsampling=0)
