"""Re-cut Margaret Toigo's CC0 Single wardrobe for Makabe, keeping its UVs and ten bones."""
from pathlib import Path
import struct,sys
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.ndimage import distance_transform_edt,gaussian_filter,grey_opening
from PIL import Image
source,out=map(Path,sys.argv[1:]);buf=(source/'Single.bytes').read_bytes();nv,ni=struct.unpack_from('<ii',buf)
data=np.ndarray((nv,8),'<f4',buffer=buf,offset=8,strides=(52,4)).copy()
ids=np.ndarray((nv,4),'u1',buffer=buf,offset=40,strides=(52,1)).copy()
rawweights=np.ndarray((nv,4),'<f4',buffer=buf,offset=44,strides=(52,4)).copy()
faces=np.frombuffer(buf,'<u2',count=ni,offset=8+nv*52).reshape(-1,3).copy()
p=data[:,:3].astype(float);n0=data[:,3:6].astype(float);tex=data[:,6:8];x,y,z=p.T.copy()
unique,rev=np.unique(np.round(p,5),axis=0,return_inverse=True)
src=rev[faces].ravel();dst=rev[faces[:,[1,2,0]]].ravel()
_,labels=connected_components(coo_matrix((np.ones(len(src)),(src,dst)),shape=(len(unique),len(unique))).tocsr(),directed=False);labels=labels[rev]
jacket=labels==np.bincount(labels).argmax()
def ramp(lo,hi,v):
 t=np.clip((v-lo)/(hi-lo),0,1);return t*t*(3-2*t)
def gauss(v,c,w):return np.exp(-((v-c)/w)**2)
w=np.zeros((nv,10));np.add.at(w,(np.arange(nv)[:,None],ids),rawweights)
arm=w[:,2:6].sum(1)
body=jacket*(1-ramp(.12,.74,arm))
back=body*ramp(.030,.094,-z)
# Two separate blades, dropped waist, and a pressed centre seam. Preserve the inner/outer gap of the vent.
ax=np.abs(x);blade=gauss(ax,.088,.061)*gauss(y,1.289,.078)
seam=gauss(x,0,.009)*ramp(.98,1.07,y)*(1-ramp(1.36,1.42,y))
p[:,2]+=back*(.0030*seam-.0082*blade+.0038*gauss(y,1.086,.056)*gauss(ax,.066,.068))
# A shoulder blade presses against the cloth above a short, sloping fold. The armhole
# gives this crease an endpoint. It does not run across the centre as an ornamental stripe.
scye=gauss(ax,.128,.059)*ramp(.040,.080,ax)
bias=1.185+.59*ax+.007*np.sin(14*x)
p[:,2]+=back*scye*(-.0074*gauss(y,bias,.021)+.0033*gauss(y,bias-.024,.018))
drape=back*gauss(ax,.111,.051)*gauss(y,.974+.34*ax,.035)
p[:,2]-=.0031*drape
p[:,0]*=1-body*.027*gauss(y,1.074,.080)
shoulderTop=jacket*gauss(y,1.352,.055)*ramp(.120,.220,ax)
p[:,1]-=shoulderTop*.0031
lower=body*(1-ramp(.847,1.011,y))
p[:,1]-=lower*(.012+.008*ramp(0,.10,-z))
p[:,2]-=lower*ramp(.045,.105,-z)*(.005+.0065*gauss(x,.013,.022))
# The left lap overlaps the right down the centre vent.
p[:,0]+=lower*ramp(.066,.108,-z)*(.0034*np.tanh((x-.002)/.014))*gauss(x,.005,.047)
collar=jacket*ramp(1.375,1.429,y)*(1-ramp(.080,.130,ax))
p[:,1]+=.004*collar;p[:,2]-=.0023*collar*ramp(.025,.065,-z)
# Share a little forward pull from each sleeve cap with the adjacent back panel.
for side,upper in [(-1,2),(1,4)]:
 patch=back*gauss(x,side*.145,.054)*gauss(y,1.316,.072)*.14
 transfer=np.minimum(w[:,1],patch)
 w[:,1]-=transfer;w[:,upper]+=transfer
# A coat hem swings on the pelvis. Allow a fraction of the near leg's original pull.
for bone in [6,7,8,9]:
 move=w[:,bone]*body*.58
 w[:,bone]-=move;w[:,0]+=move
weightsort=np.argsort(-w,axis=1,kind='stable')[:,:4];weights=np.take_along_axis(w,weightsort,axis=1);weights/=weights.sum(1)[:,None]
# The third geometry island is already occluded by the closed lower front. Retain both visible buttons.
drop=np.zeros(nv,dtype=bool)
def recompute(q):
 t=q[faces];area=np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]);a=np.zeros_like(unique,dtype=float)
 for ix in range(3):np.add.at(a,rev[faces[:,ix]],area)
 return a[rev]/np.maximum(1e-12,np.linalg.norm(a[rev],axis=1,keepdims=True))
def normal_after(q):
 # Retain authored normal splits/creases and apply only the change of the continuous surface.
 nn=n0+recompute(q)-recompute(data[:,:3])
 return nn/np.maximum(1e-9,np.linalg.norm(nn,axis=1,keepdims=True))
normal=normal_after(p)
correctives=[]
for side in [-1,1]:
 # Bias folds fan from a raised scye; the back broadens over the advancing shoulder blade.
 delta=np.zeros_like(p);xs=x*side
 fan=back*gauss(xs,.119,.082)*gauss(y,1.256,.093)*ramp(-.02,.075,xs)
 ridge=gauss(y,1.194+.47*xs,.022)-.64*gauss(y,1.212+.47*xs,.018)
 delta[:,2]-=fan*(.0051+.0092*ridge)
 delta[:,0]+=side*fan*.0088
 delta[:,1]+=fan*.0067
 hem=lower*ramp(.040,.129,xs)*(.4+.6*ramp(-.015,.101,-z))
 delta[:,1]+=hem*.009;delta[:,2]-=hem*.0043
 # Ease the sleeve head without moving cuffs, shirt fronts, buttons or trousers.
 sleeve=jacket*arm*gauss(xs,.197,.048)*gauss(y,1.306,.071)
 delta[:,1]+=sleeve*.0032;delta[:,2]+=sleeve*.0041
 correctives.append((delta,normal_after(p+delta)-normal))
keep=np.where(~drop)[0];lookup=np.zeros(nv,dtype=int);lookup[keep]=np.arange(len(keep))
# Use the second UV set for individual yarns. Distance per UV unit is measured independently
# for each existing jacket chart. The other garment islands sample a flat normal.
cornerStart=faces.ravel();cornerEnd=faces[:,[1,2,0]].ravel()
_,chart=connected_components(coo_matrix((np.ones(len(cornerStart)),(cornerStart,cornerEnd)),shape=(nv,nv)).tocsr(),directed=False)
detailuv=np.full((nv,2),.5/256)
period=.0128
for label in np.unique(chart[jacket]):
 selection=faces[chart[faces[:,0]]==label];coords=tex[selection];m=p[selection]
 a=coords[:,1]-coords[:,0];b=coords[:,2]-coords[:,0];du=m[:,1]-m[:,0];dv=m[:,2]-m[:,0];det=a[:,0]*b[:,1]-a[:,1]*b[:,0];valid=np.abs(det)>1.e-8
 if not valid.any():continue
 ex=(du*b[:,1,None]-dv*a[:,1,None])[valid]/det[valid,None]
 ey=(dv*a[:,0,None]-du*b[:,0,None])[valid]/det[valid,None]
 scale=np.median([np.linalg.norm(ex,axis=1),np.linalg.norm(ey,axis=1)],axis=1)
 detailuv[chart==label]=tex[chart==label]*np.clip(scale,.18,2.5)/period
with (out/'MakabeCut.bytes').open('wb') as file:
 file.write(struct.pack('<ii',len(keep),faces.size))
 for i in keep:file.write(struct.pack('<8f4B4f',*p[i],*normal[i],*tex[i],*weightsort[i],*weights[i]))
 file.write(lookup[faces].astype('<u2').tobytes())
 # Sparse signed 16-bit deltas in 0.01 mm / 1e-4 normal units.
 for deform,normals in correctives:
  active=keep[np.linalg.norm(deform[keep],axis=1)>.000035]
  file.write(struct.pack('<i',len(active)))
  for i in active:file.write(struct.pack('<H6h',lookup[i],*np.rint(deform[i]*1e5).astype(int),*np.rint(normals[i]*1e4).astype(int)))
 file.write(detailuv[keep].astype('<f4').tobytes())
print('vertices',len(keep),'triangles',len(faces),'corrective max mm',[round(np.max(np.linalg.norm(dp,axis=1))*1000,2) for dp,_ in correctives])

# Rasterise metre-space cloth coordinates onto Toigo's original UV charts, so a sleeve's weave is
# measured along its circumference rather than scaling differently on each arbitrarily packed chart.
N=2048
mapping=np.zeros((N,N,4),dtype=np.float32);cover=np.zeros((N,N),bool)
for face in faces[jacket[faces[:,0]]]:
 u=tex[face].astype(float)*N;u[:,1]=N-u[:,1]
 xmin,ymin=np.maximum(0,np.floor(u.min(0)).astype(int));xmax,ymax=np.minimum(N-1,np.ceil(u.max(0)).astype(int))
 yy,xx=np.mgrid[ymin:ymax+1,xmin:xmax+1];xx=xx+.5;yy=yy+.5
 a,b=u[1]-u[0],u[2]-u[0];det=a[0]*b[1]-b[0]*a[1]
 if abs(det)<1e-8:continue
 wa=((xx-u[0,0])*b[1]-(yy-u[0,1])*b[0])/det;wb=(a[0]*(yy-u[0,1])-a[1]*(xx-u[0,0]))/det
 sel=(wa>=0)&(wb>=0)&(wa+wb<=1)
 if not sel.any():continue
 attr=np.column_stack([p[face],arm[face]]);q=attr[0]+(attr[1]-attr[0])*wa[:,:,None]+(attr[2]-attr[0])*wb[:,:,None]
 mapping[ymin:ymax+1,xmin:xmax+1][sel]=q[sel];cover[ymin:ymax+1,xmin:xmax+1][sel]=True
dist,nearest=distance_transform_edt(~cover,return_indices=True);area=dist<5
py,px=np.where(area);ny,nx=nearest[:,py,px]
X,Y,Z,A=mapping[ny,nx].T
# Continuous grain around the body and down each tube. The selvage direction stays vertical.
torso=np.arctan2(X,-Z)*.151
sleeve=np.arctan2(X-np.sign(X)*.196,-Z)*.047
g=torso*(1-ramp(.2,.80,A))+sleeve*ramp(.2,.80,A)
wales=.0064;phase=np.abs(np.mod(g/wales,2)-1)*wales
thread=.00125
twill=np.cos(2*np.pi*(Y+.73*phase)/thread)
wool=np.sin(2*np.pi*g/.00102)*np.sin(2*np.pi*Y/.00107)
rng=np.random.default_rng(7019);noise=rng.normal(0,1,len(Y))
old=np.array(Image.open(source/'Navy.jpg').convert('RGB').resize((N,N),Image.Resampling.LANCZOS))
base=old[py,px].astype(float)
# Preserve the original light and pocket stitching; lower the blue cast toward blue-black charcoal.
# Lift out the donor suit's painted pinstripe while retaining the larger pocket and lapel shadows.
luminance=np.asarray(Image.fromarray(old).convert('L'),dtype=np.float32)
broad=gaussian_filter(grey_opening(luminance,size=(7,7)),1.3)
luma=broad[py,px];mottle=1+.073*twill+.036*wool+.020*noise
replacement=np.stack([luma*.76+3,luma*.83+4,luma*.915+5],axis=1)*mottle[:,None]
rear=ramp(.035,.105,-Z)*(1-ramp(.3,.7,A))
center=np.abs(X-.001);ridge=np.exp(-((center-.0017)/.0011)**2)*rear
ventY=1-ramp(.966,1.026,Y);vent=gauss(X,.006,.0035)*rear*ventY
collarSeam=gauss(Y,1.409-.003*np.cos(X*29),.00125)*rear*(1-ramp(.054,.081,np.abs(X)))
wear=(gauss(np.abs(X),.15,.035)*gauss(Y,1.347,.024)+.42*A*gauss(Y,1.085,.034))*.034
replacement*=1+wear[:,None]
replacement*=1-.23*ridge[:,None]-.23*vent[:,None]-.16*collarSeam[:,None]
# Broken 3-mm pick stitches along the back seam and collar, in the same dyed yarn.
stitch=(np.cos(2*np.pi*Y/.0047)>.16)*gauss(center,.0032,.0008)*rear
replacement+=stitch[:,None]*np.array([5,4.5,4])
old[py,px]=np.uint8(np.clip(replacement,0,255));Image.fromarray(old).save(out/'MakabeWool.jpg',quality=94,subsampling=0)
normalmap=np.asarray(Image.open(source/'SingleNormal.png').convert('RGB').resize((N,N),Image.Resampling.LANCZOS)).copy()
height=np.zeros((N,N),np.float32);height[py,px]=(.32*twill+.14*wool+.09*noise-.62*ridge-.8*vent+.26*stitch)
dy,dx=np.gradient(gaussian_filter(height,.6))
baseNormal=np.stack([gaussian_filter(normalmap[:,:,k].astype(np.float32),1.65) for k in range(3)],axis=-1)
vec=baseNormal[py,px]/127.5-1;vec[:,0]-=dx[py,px]*.54;vec[:,1]+=dy[py,px]*.54
vec/=np.maximum(1e-9,np.linalg.norm(vec,axis=1,keepdims=True));normalmap[py,px]=np.uint8(np.clip((vec+1)*127.5,0,255));Image.fromarray(normalmap).save(out/'MakabeWoolNormal.png')

# Forty yarns across a 12.8-mm repeat. Alternating raised warp/weft describes a four-thread twill.
t,v=np.meshgrid((np.arange(256)+.5)/256,(np.arange(256)+.5)/256)
gx=t*40;gy=v*40;sign=np.where(t<.5,1,-1)
warp=.5+.5*np.cos(gx*2*np.pi);weft=.5+.5*np.cos(gy*2*np.pi)
cross=.5+.5*np.sin((np.floor(gx)*sign+np.floor(gy))*.5*np.pi)
height=.034*(cross*warp**.80+(1-cross)*weft**.80)+.002*np.cos((gx+gy)*2*np.pi)
# A neutral sample for the shirt, tie, trousers and buttons, which do not use this weaving.
dy=(np.roll(height,-1,0)-np.roll(height,1,0))/.1;dx=(np.roll(height,-1,1)-np.roll(height,1,1))/.1
tangent=np.stack([-dx,dy,np.ones_like(dx)],axis=-1);tangent/=np.linalg.norm(tangent,axis=2,keepdims=True)
rgb=np.uint8(np.clip((tangent+1)*127.5,0,255));rgb[-3:,:3]=[128,128,255]
tint=np.uint8(np.clip(height/.036*255,0,255));Image.fromarray(np.dstack([rgb,tint])).save(out/'WorstedThreads.png')
