"""Original deterministic wardrobe surface maps, not an extraction of wardrobe.png."""
from pathlib import Path
from PIL import Image
import numpy as np
out=Path(__file__).resolve().parents[2]/'Game/Assets/Resources/KinseiHallWardrobe'
out.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(1414);n=1024;y,x=np.mgrid[:n,:n]
noise=rng.normal(0,1,(n,n));weave=(np.sin(x*np.pi)+np.cos(y*np.pi*.5))*.02
# One repeat represents 128 mm; eight pinstripes = restrained 16 mm spacing.
a=np.ones((n,n,3))*np.array([.64,.70,.88]);a*= (1+noise*.035+weave)[...,None]
d=np.minimum(x%128,128-x%128);line=np.exp(-.5*(d/1.4)**2)*.42
a+=line[...,None]*np.array([.35,.40,.53]);Image.fromarray(np.uint8(np.clip(a,0,1)*255)).save(out/'KontaniPinstripe.png')
# Balanced red/brown yarns with irregular pale flecks; medium albedo prevents crushed blacks.
a=np.ones((n,n,3))*np.array([.78,.66,.64]);grain=noise*.045+np.sin((x+y)*np.pi*.5)*.027+np.sin((x-y)*np.pi*.25)*.015
a+=grain[...,None];Image.fromarray(np.uint8(np.clip(a,0,1)*255)).save(out/'UraMulberryWool.png')
# Original acetate marbling, no photographic or third-party pattern source.
n=256;y,x=np.mgrid[:n,:n];m=np.sin(x*.051+np.sin(y*.046)*2)+np.sin(y*.071+x*.03)+rng.normal(0,.08,(n,n));m=np.clip((m+.4)*.6,0,1)
a=np.array([.12,.045,.018])[None,None,:]*(1-m[...,None])+np.array([.58,.29,.075])[None,None,:]*m[...,None]
Image.fromarray(np.uint8(a*255)).save(out/'Tortoiseshell.png')
