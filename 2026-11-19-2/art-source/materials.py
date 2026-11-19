"""Build a trim sheet from the project's Moss-image lighting and material reference frames."""
import bpy
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"Game/Assets/Resources/World"
SIZE=256
def read_image(path):
    im=bpy.data.images.load(str(path),check_existing=True)
    w,h=im.size
    buf=np.empty(w*h*4,np.float32);im.pixels.foreach_get(buf)
    return np.flipud(buf.reshape(h,w,4))[:,:,:3]
mobile=read_image(ROOT/"art/station-mobile.webp")
fps=read_image(ROOT/"art/station-fps.webp")
command=read_image(ROOT/"art/station-command.webp")
def patch(im,rect):
    x,y,r,b=rect
    ys=np.linspace(y,b-1,SIZE//2).astype(int);xs=np.linspace(x,r-1,SIZE//2).astype(int)
    q=im[np.ix_(ys,xs)]
    mirror=np.concatenate((q,q[:,::-1]),axis=1)
    return np.concatenate((mirror,mirror[::-1]),axis=0)
# Asphalt, wall render, brushed stainless, blue reflective glass, painted steel, woven coat and rubber.
parts=[
    (mobile,(260,408,514,542)),(fps,(38,346,112,400)),
    (mobile,(1357,150,1447,368)),(fps,(1037,230,1111,289)),
    (mobile,(317,180,338,314)),(mobile,(791,321,880,497)),
    (mobile,(501,644,545,675)),(mobile,(1205,298,1233,475)),
    (fps,(457,240,497,262)),(mobile,(906,134,954,165)),
    (fps,(638,46,660,121)),(fps,(381,491,432,539)),
    (fps,(643,581,703,613)),(mobile,(1010,40,1056,70)),
    (mobile,(862,284,899,318)),(mobile,(890,594,914,626))]
out=np.ones((SIZE*4,SIZE*4,4),np.float32)
for k,(im,rect) in enumerate(parts):
    q=patch(im,rect)
    lum=q@np.array([.24,.67,.09])
    low,mid,high=np.percentile(lum,(3,50,97))
    detail=np.clip((lum-mid)/max(high-low,.026),-1.0,1.0)
    # Neutral detail preserves the authored paint families. Source tint is retained in glass and paving.
    chroma=(q-lum[:,:,None])/(.17+lum[:,:,None])
    col=np.clip(.50+detail[:,:,None]*.60+chroma*.16,.06,.97)
    tile=np.ones((SIZE,SIZE,4),np.float32);tile[:,:,:3]=col
    row,colidx=divmod(k,4)
    out[row*SIZE:(row+1)*SIZE,colidx*SIZE:(colidx+1)*SIZE]=tile
atlas=bpy.data.images.new("Moss material study",width=SIZE*4,height=SIZE*4,alpha=False)
atlas.colorspace_settings.name="Non-Color"
atlas.pixels.foreach_set(np.flipud(out).reshape(-1))
atlas.filepath_raw=str(OUT/"MossMaterials.jpg");atlas.file_format="JPEG";atlas.save()
