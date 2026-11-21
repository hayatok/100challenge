"""Bake Margaret Toigo's MakeHuman suits onto the KinseiActor rest skeleton.
Usage: python bake.py /path/to/suits01_cc0.zip
"""
import sys
import struct
import zipfile
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "Game/Assets/Resources/KinseiWardrobe"


def ramp(lo, hi, value):
    t = np.clip((value-lo)/(hi-lo), 0, 1)
    return t*t*(3-2*t)


def fit(vertices, double):
    points, influences = [], []
    wrist = np.array([4.86, 2.9, 1.64]) if double else np.array([4.92, 2.60, 1.71])
    shoulder = np.array([1.99, 5.93, .27])
    along = wrist-shoulder
    span = np.linalg.norm(along)
    along /= span
    across = np.array([-along[1], along[0], 0])
    across /= np.linalg.norm(across)
    forward = np.cross(across, along)*-1
    for x,y,z in vertices:
        s = -1 if x < 0 else 1
        ax = abs(x)
        leg = 1-ramp(-1.5,.85,y)
        # Neutral MakeHuman trousers straddle widely at their hems.
        spread = np.interp(y, [-7.55,-3.6,-.6,1], [1.17,.68,.20,0])
        p = np.array([.099*(ax-spread*leg), np.interp(y,[-7.65,-3.7,0,5.93,7.37],[.069,.505,.864,1.349,1.46]), (z-.39)*.091])
        # Rotate each sleeve's anatomical A-pose about its shoulder into actor rest space.
        delta = np.array([ax,y,z])-shoulder
        u = delta @ along / span
        arm = ramp(1.62,2.50,ax) * ramp(.7,1.7,y)
        sleeve = np.array([.196+(delta@across)*.098,1.345-u*.509,.004+(delta@forward)*.093])
        p = p*(1-arm)+sleeve*arm
        p[0] *= s
        points.append(p)
        hip, knee, upper, elbow = (6,7,2,3) if s<0 else (8,9,4,5)
        thigh = (1-ramp(.805,.98,p[1]))*(1-arm)
        shin = 1-ramp(.435,.595,p[1])
        forearm = ramp(.394,.625,u)
        spine = ramp(.88,1.16,p[1])
        weights = {upper:arm*(1-forearm),elbow:arm*forearm,hip:thigh*(1-shin),knee:thigh*shin,
                   1:(1-arm-thigh)*spine,0:(1-arm-thigh)*(1-spine)}
        selected = sorted(weights.items(),key=lambda i:-i[1])[:4]
        total=sum(w for _,w in selected)
        influences.append(([i for i,_ in selected],[max(0,w)/total for _,w in selected]))
    return np.array(points), influences


def mesh(data, key, double):
    lines = data.decode().splitlines()
    vertices = np.array([list(map(float,l.split()[1:4])) for l in lines if l.startswith("v ")])
    uv = [tuple(map(float,l.split()[1:3])) for l in lines if l.startswith("vt ")]
    pos, weights = fit(vertices, double)
    indices, corners, faces = {}, [], []
    normals = np.zeros_like(pos)
    for line in lines:
        if not line.startswith("f "): continue
        poly = []
        for token in line.split()[1:]:
            v,t = (int(i)-1 for i in token.split("/")[:2])
            if (v,t) not in indices:
                indices[v,t] = len(corners)
                corners.append((v,t))
            poly.append(indices[v,t])
        for j in range(1,len(poly)-1):
            tri = [poly[0],poly[j],poly[j+1]]
            v = [corners[i][0] for i in tri]
            n = np.cross(pos[v[1]]-pos[v[0]],pos[v[2]]-pos[v[0]])
            normals[v] += n
            faces.extend(tri)
    normals /= np.maximum(1e-9,np.linalg.norm(normals,axis=1,keepdims=True))
    with (OUT/(key+".bytes")).open("wb") as f:
        f.write(struct.pack("<ii",len(corners),len(faces)))
        for v,t in corners:
            bones, amounts = weights[v]
            f.write(struct.pack("<8f4B4f",*pos[v],*normals[v],*uv[t],*bones,*amounts))
        f.write(np.asarray(faces,dtype="<u2").tobytes())
    print(key,len(corners),len(faces)//3)


def textures(z, directory, prefix, key, palettes):
    def read(suffix):
        data=z.read(directory+prefix+suffix+".png")
        return Image.open(BytesIO(data)).convert("RGB").resize((1024,1024),Image.Resampling.LANCZOS)
    read("-norm").save(OUT/(key+"Normal.png"))
    rgb=np.array(read(""),dtype=float)
    r,g,b=rgb.transpose(2,0,1)
    lum=.30*r+.59*g+.11*b
    if key=="Double":
        cloth=(b>r*1.1)&(b>g*1.08)
        shirt=(g>115)&(r>105)&(~cloth)
        # The necktie has a separate green UV island.
        yy,xx=np.indices(r.shape)
        tie=shirt&(xx<390)&(yy<390)
    else:
        cloth=(b>r*1.13)&(r<120)
        shirt=(g>110)&(b>110)&(~cloth)
        tie=(r>g*1.32)&(r>b*1.15)
    for name,base in palettes.items():
        out=rgb.copy()
        for mask,color,median in [(cloth,base,56 if key=="Double" else 34),(shirt,(218,209,182),185),(tie,(82,31,39),100)]:
            out[mask]=np.clip((lum[mask,None]/median)**.72,.36,1.65)*np.array(color)
        Image.fromarray(np.uint8(np.clip(out,0,255))).save(OUT/(name+".jpg"),quality=94,subsampling=0)


if __name__=="__main__":
    with zipfile.ZipFile(sys.argv[1]) as source:
        for directory,obj,prefix,key,roles in [
            ("toigo_male_suit_3","suit3","NewSuit3","Single",{"Navy":(40,46,57),"Cream":(207,195,169),"Olive":(79,76,57),"Sage":(62,74,58)}),
            ("toigo_male_double-breasted_suit","suit_double_breasted","DB-suit","Double",{"Rust":(147,76,49)})]:
            directory="clothes/"+directory+"/"
            mesh(source.read(directory+obj+".obj"),key,key=="Double")
            textures(source,directory,prefix,key,roles)

