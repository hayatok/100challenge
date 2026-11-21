"""Build Makabe's opaque side part on the imported adult head. Inputs and output are in metres."""
import argparse
from pathlib import Path
import json
import numpy as np
from scipy.spatial import cKDTree

def read_obj(path):
    xyz=[]; uv=[]; faces=[]
    for row in path.read_text().splitlines():
        w=row.split()
        if w and w[0]=='v':xyz.append([float(x) for x in w[1:4]])
        elif w and w[0]=='vt':uv.append([float(x) for x in w[1:3]])
        elif w and w[0]=='f':
            ids=[int(x.split('/')[0])-1 for x in w[1:]]
            faces.extend((ids[0],ids[i],ids[i+1]) for i in range(1,len(ids)-1))
    return np.array(xyz),np.array(uv),np.array(faces)
def normalized(a):return a/np.maximum(np.linalg.norm(a,axis=-1,keepdims=True),1e-12)
def smooth(x):x=np.clip(x,0,1);return x*x*(3-2*x)
def directions(a,p):return np.stack((np.sin(a)*np.sin(p),np.cos(p),np.cos(a)*np.sin(p)),axis=-1)

class Scalp:
    center=np.array([-.005,.105,-.014])
    def __init__(self,head=None,triangles=None):
        if triangles is None:
            verts,_,faces=read_obj(head)
            triangles=verts[faces]
        tris=triangles-self.center
        self.a=tris[:,0];self.e=tris[:,1]-self.a;self.f=tris[:,2]-self.a
        self.q=np.cross(-self.a,self.e);self.n=np.einsum('ij,ij->i',self.f,self.q)
        self.tree=cKDTree(normalized(tris.mean(1)))
    def hit(self,direction):
        d=np.atleast_2d(direction);radi=[]
        for off in range(0,len(d),128):
            ray=d[off:off+128];_,ids=self.tree.query(ray,k=80)
            p=np.cross(ray[:,None,:],self.f[ids]);den=np.sum(p*self.e[ids],axis=2)
            den=np.where(abs(den)<1e-12,np.inf,den)
            u=np.sum(p*-self.a[ids],axis=2)/den
            v=np.sum(ray[:,None,:]*self.q[ids],axis=2)/den
            t=self.n[ids]/den
            distances=np.amax(np.where((u>=-1e-7)&(v>=-1e-7)&(u+v<=1+1e-7)&(t>0),t,0),axis=1)
            if np.any(distances<=0):raise ValueError("uncovered scalp direction")
            radi.extend(distances)
        return np.array(radi)

class Groom:
    def __init__(self,scalp):
        self.scalp=scalp
        self.angles=np.linspace(-np.pi,np.pi,721)
        degrees=abs(np.degrees(self.angles))
        # Sideburn in front of the pinna, high arch over the helix, taper below the occiput.
        knots=[0,18,34,46,55,59,63,65,67,70,76,84,91,98,110,131,157,180]
        heights=[.155,.159,.169,.161,.146,.120,.079,.068,.073,.098,.111,.112,.105,.084,.063,.046,.038,.036]
        y=np.interp(degrees,knots,heights)+.002*np.sin(self.angles*2)
        y+=.00065*np.sin(self.angles*29+.55)+.00042*np.sin(self.angles*47)
        lo=np.zeros(len(y));hi=np.full(len(y),2.75)
        for _ in range(14):
            t=(lo+hi)/2;d=directions(self.angles,t)
            mapped=scalp.center[1]+d[:,1]*scalp.hit(d)
            lo=np.where(mapped>y,t,lo);hi=np.where(mapped>y,hi,t)
        self.ends=(lo+hi)/2
        self.part=-.39
    def surface(self,u,v):
        a=u*2*np.pi-np.pi
        # The long bank crosses the crown toward the short side. The nape remains combed down.
        sweep=(.79+.35*np.cos(a)+.20*np.sin(2*a))*np.maximum(0,1-v)**1.25
        theta=a+sweep*(1-smooth((v-.36)/.28))
        end=np.interp(theta,self.angles,self.ends,period=2*np.pi)
        p=np.clip(v,0,1.07)*(.76+(end-.76)*smooth((v-.64)/.36))
        d=directions(theta,p);r=self.scalp.hit(d)
        crown=smooth(v/.12)*smooth((1-v)/.22)
        ridge=np.maximum(0,np.cos(2*np.pi*(u*26+.13*np.sin(a*3+v*4))))**3
        delta=np.arctan2(np.sin(a-self.part),np.cos(a-self.part))
        part=np.exp(-(delta/.065)**2)*smooth((v-.13)/.14)*smooth((1-v)/.09)
        volume=.0004+.004*(1-v)+.0070*np.maximum(0,1-v)**.65+(.0053*(.55+.45*np.cos(a-.55))+.0009*ridge)*crown
        volume*=1-.90*part
        return self.scalp.center+d*(r+volume)[:,None],d,volume

def build(head,target):
    surface=Groom(Scalp(head));verts=[];uv=[];faces=[];kinds=[]
    def vertex(p,tex):
        verts.append(p);uv.append(tex);return len(verts)-1
    def tri(a,b,c,kind):faces.append((a,b,c));kinds.append(kind)
    # Circumferential seam uses the same positional vertex and a separate UV index at export.
    steps,rings=144,35
    top=vertex(surface.surface(np.array([.5]),np.array([0.]))[0][0],(.5,0))
    u=np.tile(np.arange(steps)/steps,rings)
    v=np.repeat(np.linspace(1/rings,1,rings),steps)
    points,_,_=surface.surface(u,v)
    grid=np.array([vertex(p,(uu,vv)) for p,uu,vv in zip(points,u,v)]).reshape(rings,steps)
    for i in range(steps):
        j=(i+1)%steps;tri(top,grid[0,i],grid[0,j],0)
        for row in range(rings-1):
            a,b=grid[row,i],grid[row,j];c,d=grid[row+1,i],grid[row+1,j]
            tri(a,c,b,0);tri(b,c,d,0)
    # Check the triangles, not just their control vertices. A coarse chord at the root
    # of an ear can cross the bent ear helix even when its three pins are outside.
    outer=np.array(faces);base=np.array(verts)
    for iteration in range(4):
        raise_by=np.zeros(len(base));min_gap=1
        for bary in ((1/3,1/3,1/3),(.5,.5,0),(.5,0,.5),(0,.5,.5)):
            test=np.einsum('ijk,j->ik',base[outer],bary)-surface.scalp.center
            clearance=np.linalg.norm(test,axis=1)-surface.scalp.hit(normalized(test))
            min_gap=min(min_gap,float(clearance.min()))
            bad=clearance<.00005
            if np.any(bad):
                for ids in outer[bad].T:np.maximum.at(raise_by,ids,np.minimum(.0018,.00017-clearance[bad]))
        if not np.any(raise_by):break
        base+=normalized(base-surface.scalp.center)*raise_by[:,None]
    verts=list(base)
    carrier=Scalp(triangles=base[outer]);root_depths=[]
    rim=base[grid[-1]];edge=normalized(rim-surface.scalp.center)
    inner=surface.scalp.center+edge*(surface.scalp.hit(edge)-.0016)[:,None]
    skirt=[vertex(p,(i/steps,1.015)) for i,p in enumerate(inner)]
    # All closure triangles are hidden by the underlying head.
    center=vertex(surface.scalp.center,(.5,1.05))
    for i in range(steps):
        j=(i+1)%steps;tri(grid[-1,i],skirt[i],grid[-1,j],1);tri(grid[-1,j],skirt[i],skirt[j],1);tri(center,skirt[j],skirt[i],1)
    rng=np.random.default_rng(101)
    # Low, solid lozenge-shaped locks. Both tips and the undersides pass through the base.
    nlock=112;controls=[];anchors=[]
    for i in range(nlock):
        uu=(i+.45+rng.uniform(-.22,.22))/nlock
        angle=uu*2*np.pi-np.pi
        if abs(angle-surface.part)<.038:continue
        near_edge=i%3!=0
        start=rng.uniform(.62,.88) if near_edge else rng.uniform(.11,.48)
        end=rng.uniform(.97,.996) if near_edge else rng.uniform(.60,.92)
        stations=11;f=np.linspace(0,1,stations);v=start+(end-start)*f
        u=uu+.009*np.sin(f*np.pi)*(1 if np.sin(angle-surface.part)>0 else -1)+.002*np.sin(f*2*np.pi+.6)
        points,out,_=surface.surface(u,v)
        # Project every crest control to the actual tessellated shell; a smooth ideal
        # surface alone can put the crest intermittently under a long triangular chord.
        points=carrier.center+out*(carrier.hit(out)+.00004)[:,None]
        tangent=normalized(np.gradient(points,axis=0))
        width=rng.uniform(.00065,.00145) if near_edge else rng.uniform(.0010,.0021)
        height=rng.uniform(.00045,.00105)
        side=normalized(np.cross(tangent,out));normal=normalized(np.cross(side,tangent))
        contour=np.sin(np.pi*f)**.68
        # The strand ends are rooted below even the faceted carrier. No floating transparent cards.
        points-=normal*(.0009*(1-contour))[:,None]
        # Place the roots against the exported carrier triangles as well as the ideal surface.
        ends=points[[0,-1]]-carrier.center;ray=normalized(ends);radius=carrier.hit(ray)
        depth=np.maximum(radius-np.linalg.norm(ends,axis=1),.00032)
        points[[0,-1]]=carrier.center+ray*(radius-depth)[:,None];root_depths.extend(depth)
        a=vertex(points[0],(u[0],v[0]));rows=[]
        for j in range(1,stations-1):
            rows.append([vertex(points[j]+side[j]*(dx*width*contour[j])+normal[j]*(dy*height*contour[j]),(u[j]+dx*.002,v[j]))
                         for dx,dy in [(-1,-.24),(0,1),(1,-.24),(0,-1.1)]])
        b=vertex(points[-1],(u[-1],v[-1]))
        # Orient every closed strand to positive signed volume before appending.
        tf=[]
        for k in range(4):
            n=(k+1)%4;tf.append((a,rows[0][n],rows[0][k]))
            for j in range(len(rows)-1):
                aa,bb=rows[j][k],rows[j][n];cc,dd=rows[j+1][k],rows[j+1][n]
                tf.extend([(aa,bb,cc),(bb,dd,cc)])
            tf.append((b,rows[-1][k],rows[-1][n]))
        local=np.array([[verts[q] for q in face] for face in tf])-points[0]
        signed=np.einsum('ij,ij->i',local[:,0],np.cross(local[:,1],local[:,2])).sum()
        for a,b,c in tf:tri(a,b,c,2) if signed>0 else tri(c,b,a,2)
        controls.append([uu,start,end,width,height]);anchors.extend(points[[0,-1]])
    verts=np.array(verts);uv=np.array(uv);faces=np.array(faces);kinds=np.array(kinds)
    # Round the outer coat and the individual crests. Keep the hidden base from biasing boundary normals.
    normals=np.zeros_like(verts)
    pt=verts[faces];cross=np.cross(pt[:,1]-pt[:,0],pt[:,2]-pt[:,0])
    for i in range(3):np.add.at(normals,faces[kinds!=1,i],cross[kinds!=1])
    rimN=normalized(rim-surface.scalp.center);normals[skirt]=rimN;normals[center]=[0,-1,0];normals=normalized(normals)
    lines=['o MakabeGroom']
    lines.extend('v %.7f %.7f %.7f'%tuple(p) for p in verts)
    exportUV=list(uv);indices=[];wrapped={}
    for face in faces:
        us=uv[face,0];t=[]
        for idx in face:
            if us.max()-us.min()>.55 and uv[idx,0]<.5:
                if idx not in wrapped:
                    wrapped[idx]=len(exportUV);exportUV.append(uv[idx]+[1,0])
                t.append(wrapped[idx])
            else:t.append(idx)
        indices.append(t)
    lines.extend('vt %.7f %.7f'%tuple(p) for p in exportUV)
    lines.extend('vn %.7f %.7f %.7f'%tuple(n) for n in normals)
    lines.extend('f '+' '.join('%d/%d/%d'%(idx+1,t+1,idx+1) for idx,t in zip(face,tex)) for face,tex in zip(faces,indices))
    target.write_text('\n'.join(lines)+'\n',encoding='ascii')
    from collections import Counter
    edges=Counter(tuple(sorted((a,b))) for face in faces for a,b in zip(face,np.roll(face,-1)))
    radii=np.linalg.norm(rim-surface.scalp.center,axis=1)
    offsets=(radii-surface.scalp.hit(edge))*1000
    outside=(kinds==0);flat=normalized(cross[outside]);outward=normalized(verts[faces[outside]].mean(1)-surface.scalp.center)
    data=dict(vertices=len(verts),triangles=len(faces),closed_locks=len(controls),nonmanifold_edges=sum(count!=2 for count in edges.values()),
       reversed_outer_faces=int((np.sum(flat*outward,axis=1)<0).sum()),hairline_clearance_mm=[float(offsets.min()),float(offsets.max())],
       minimum_sampled_scalp_clearance_mm=round(min_gap*1000,3),minimum_tuft_embedding_mm=round(min(root_depths)*1000,3),underside_embedding_mm=1.6,source_bounds_metres=read_obj(head)[0].min(0).tolist()+read_obj(head)[0].max(0).tolist())
    print(json.dumps(data,indent=2));return data

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('head',type=Path);p.add_argument('out',type=Path);p.add_argument('--measure',type=Path)
    args=p.parse_args();report=build(args.head,args.out)
    if args.measure:args.measure.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
