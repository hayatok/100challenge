"""Compose an authored 4 x 4 finish atlas, including the enamel badge in the generated reference."""
from pathlib import Path
import sys
import numpy as np
from PIL import Image,ImageFilter
src,out=map(Path,sys.argv[1:]);N=256
rng=np.random.default_rng(1971)
colors=[(181,183,179),(162,129,73),(102,78,45),(46,44,41),(41,35,30),(41,50,48),(195,195,190),(64,16,25),(108,100,81),(31,29,26)]
properties=[(.74,.55),(.69,.53),(.6,.4),(.72,.47),(.01,.23),(.08,.56),(.88,.71),(.39,.49),(.73,.42),(.02,.24)]
albedo=Image.new('RGB',(4*N,4*N),(75,65,52));metal=Image.new('RGBA',albedo.size,(0,0,0,100))
for i,(base,(met,smooth)) in enumerate(zip(colors,properties)):
 y,x=np.indices((N,N));n=rng.normal(0,1,(N,N));brush=np.sin((x+np.sin(y*.04))*.93)
 macro=np.asarray(Image.fromarray(np.uint8(rng.uniform(0,255,(16,16)))).resize((N,N),Image.Resampling.BICUBIC))/127.-1
 age=np.maximum(0,macro-.32)
 rgb=np.array(base)[None,None,:]*(1+.032*n[:,:,None]+.057*macro[:,:,None]+.022*brush[:,:,None])
 if i in [0,6,8]:
  chips=np.clip((age**1.12)*1.44+np.maximum(0,n-1.1)*.073,0,.8)
  rgb=rgb*(1-chips[:,:,None])+np.array([151,112,61])*chips[:,:,None]
 if i in [4,9]:
  weave=np.cos(2*np.pi*(x+y)*.114)*np.cos(2*np.pi*(y-x)*.114)
  rgb*=1+.21*weave[:,:,None]
 if i==7:
  # Inner gold line, enamel, gold mark, and edge damage come from the reference pixels.
  image=Image.open(src).convert('RGB').crop((934,349,1463,542)).resize((N,N),Image.Resampling.LANCZOS)
 else:image=Image.fromarray(np.uint8(np.clip(rgb,0,255)))
 tex=np.zeros((N,N,4),dtype=np.uint8);tex[:,:,0]=np.uint8(np.clip(met*(1-age*.3),0,1)*255);tex[:,:,3]=np.uint8(np.clip(smooth+.035*n-.15*age,0,1)*255);at=((i%4)*N,(3-i//4)*N)
 albedo.paste(image,at);metal.paste(Image.fromarray(tex),at)
albedo.save(out/'RibbonFinish.png');metal.save(out/'RibbonReflectance.png')
