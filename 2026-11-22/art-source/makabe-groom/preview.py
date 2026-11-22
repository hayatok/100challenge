"""CPU inspection with the source UVs and interpolated normals. No Unity or GPU required."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from build import normalized,smooth

def mesh(path):
    xyz=[];uv=[];norm=[];faces=[]
    for line in path.read_text().splitlines():
        w=line.split()
        if not w:continue
        if w[0]=='v':xyz.append(w[1:4])
        if w[0]=='vt':uv.append(w[1:3])
        if w[0]=='vn':norm.append(w[1:4])
        if w[0]=='f':
            indices=[[int(i)-1 for i in x.split('/')] for x in w[1:]]
            faces.extend((indices[0],indices[j],indices[j+1]) for j in range(1,len(indices)-1))
    f=np.array(faces)
    return np.array(xyz,float)[f[:,:,0]],np.array(uv,float)[f[:,:,1]],np.array(norm,float)[f[:,:,2]]
def tex(img,uv):
    h,w=img.shape[:2];return img[((1-uv[:,1])*h).astype(int)%h,(uv[:,0]*w).astype(int)%w]/255.
def srgb(x):return np.clip(np.where(x<.00313,12.92*x,1.055*np.power(np.maximum(x,0),1/2.4)-.055),0,1)
def linear(x):return np.where(x<.04045,x/12.92,((x+.055)/1.055)**2.4)
def shot(head,hair,skin,oldtex,az,new,light,bright):
    p,tuv,norm=[np.concatenate(pair) for pair in zip(head,hair)]
    rad=np.deg2rad(az);view=normalized(np.array([np.sin(rad),.19,np.cos(rad)]))
    xaxis=normalized(np.cross([0,1,0],view));up=np.cross(view,xaxis)
    light=normalized(np.array(light));half=normalized(light+view)
    size=(472,416);scale=1980
    xy=np.stack([size[0]/2+(p@xaxis)*scale,217-((p-[0,.139,0])@up)*scale],axis=-1)
    facing=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0])@view>0
    depth=p.mean(1)@view
    def det(a,b):return a[:,0]*b[:,1]-a[:,1]*b[:,0]
    def raster(indices):
        ids=Image.new('I',size,0);draw=ImageDraw.Draw(ids)
        for tri in indices[np.argsort(depth[indices])]:
            if facing[tri]:draw.polygon([tuple(z) for z in xy[tri]],fill=int(tri+1))
        idmap=np.array(ids)-1;yy,xx=np.nonzero(idmap>=0);tri=idmap[yy,xx];a,b,c=xy[tri].transpose(1,0,2)
        q=np.stack([xx+.5,yy+.5],axis=1)-a;b-=a;c-=a
        den=det(b,c);den=np.where(abs(den)>1e-8,den,1)
        wb=np.clip(det(q,c)/den,0,1);wc=np.clip(det(b,q)/den,0,1-wb);w=np.stack([1-wb-wc,wb,wc],axis=1)
        z=np.full(idmap.shape,-np.inf);z[yy,xx]=np.einsum('ij,ij->i',w,p[tri]@view)
        bary=np.zeros((*idmap.shape,3));bary[yy,xx]=w
        return idmap,bary,z
    ih,bh,zh=raster(np.arange(len(head[0])))
    ic,bc,zc=raster(np.arange(len(head[0]),len(p)))
    use=zc>zh;ids=np.where(use,ic,ih);yy,xx=np.nonzero(ids>=0);tri=ids[yy,xx]
    w=np.where(use[:,:,None],bc,bh)[yy,xx]
    n=normalized(np.einsum('ij,ijk->ik',w,norm[tri]));uv=np.einsum('ij,ijk->ik',w,tuv[tri])
    dif=np.maximum(0,n@light);h=np.maximum(0,n@half)
    skinmask=tri<len(head[0])
    col=linear(tex(skin,uv)[:,:3])*(.14+(.13+.70*dif[:,None])*bright)
    pick=~skinmask;u,v=uv[pick].T
    if not new:
        old=tex(oldtex,uv[pick]);col[pick]=linear(old[:,:3]*[.100,.089,.084])*(.14+(.13+.70*dif[pick,None])*bright)
        col[pick]+=(h[pick]**26*.014*dif[pick]*bright)[:,None]
    else:
        a=u*2*np.pi-np.pi;comb=u*26+.13*np.sin(3*u*2*np.pi+v*4)
        group=np.cos(comb*2*np.pi);fine=np.cos((comb*5+.21*np.sin(12*comb))*2*np.pi)
        grey=smooth((v-.67)/.31)*smooth((abs(np.sin(a))-.61)/.31)*np.maximum(0,np.cos((u*113+.21*np.sin(v*6))*2*np.pi))*.31
        pigment=linear(np.array([.235,.207,.192]))+(linear(np.array([.57,.55,.52]))-linear(np.array([.235,.207,.192])))*grey[:,None]
        seam=np.arctan2(np.sin(a+.39),np.cos(a+.39))/.062
        part=np.exp(-seam**2)*smooth((v-.13)/.19)*(1-smooth((v-.90)/.1))
        pigment*=((.86+.12*group+.07*fine)*(1+.18*part))[:,None]
        f=tri[pick];p1,p2=p[f,1]-p[f,0],p[f,2]-p[f,0];uv1=tuv[f,1]-tuv[f,0];uv2=tuv[f,2]-tuv[f,0]
        determinant=det(uv1,uv2);sign=np.where(determinant>=0,1,-1)
        direction=(p2*uv1[:,0,None]-p1*uv2[:,0,None])*sign[:,None]
        nh=n[pick];growth=normalized(direction-nh*np.sum(nh*direction,axis=1)[:,None])
        longitudinal=normalized(growth+nh*.13)@half
        sheen=np.maximum(0,1-longitudinal**2)**27*h[pick]**2*dif[pick]
        col[pick]=pigment*(.14+(.10+.90*dif[pick,None])*bright)+((.105+.026*group)*sheen*bright)[:,None]
    image=np.empty((size[1],size[0],3),dtype='uint8');image[:]=[35,39,43];image[yy,xx]=(srgb(col)*255).astype('uint8')
    return Image.fromarray(image).resize((320,282),Image.Resampling.LANCZOS)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('source',type=Path);parser.add_argument('new',type=Path);parser.add_argument('output',type=Path);args=parser.parse_args()
    src=args.source;head=mesh(src/'HeadAdult.obj');old=mesh(src/'HairAdult.obj');new=mesh(args.new)
    skin=np.array(Image.open(src/'SkinYoungStyled.png').convert('RGB'));oldtex=np.array(Image.open(src/'HairAdultGrain.png').convert('RGBA'))
    sheet=Image.new('RGB',(968,616),(25,27,30));d=ImageDraw.Draw(sheet)
    cases=[(68,[.93,.63,.13],.78,'Temple'),(154,[-.63,.70,-.48],1.05,'Nape'),(-35,[-.92,.75,.45],.92,'Part')]
    for i,(az,l,b,label) in enumerate(cases):
        for row,cap in enumerate((old,new)):
            x=i*323; y=row*308
            sheet.paste(shot(head,cap,skin,oldtex,az,row==1,l,b),(x,y+22))
            d.text((x+8,y+3),label+(' / new groom' if row else ' / original cap'),fill='#e5ddd3')
    sheet.save(args.output)
