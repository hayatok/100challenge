"""Read-only GLB audit. No mesh or source-file mutation.

OLD always means the legacy model from commit 07c2730, never the current
candidate at game/assets/models/mio.glb. The expected legacy SHA256 is
70a343c829f5e4b79802435bbd24365219cd24c5e4e38e197393aeaf9536b074.
If the ignored legacy cache is missing, restore it from the repository root:
    mkdir -p 2026-10-24-2/.cache/rework
    git show 07c2730:2026-10-24-2/game/assets/models/mio.glb > 2026-10-24-2/.cache/rework/legacy-mio.glb
Restore only a missing cache; do not overwrite either source model.
"""
import sys, struct, json, math, hashlib
from pathlib import Path

COMPONENT = {5120: ('b',1), 5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
WIDTH = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT2':4,'MAT3':9,'MAT4':16}
IDENTITY = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]

def multiply(a,b):
    return [sum(a[k*4+r]*b[c*4+k] for k in range(4)) for c in range(4) for r in range(4)]

def matrix(n):
    if 'matrix' in n: return n['matrix']
    x,y,z,w=n.get('rotation',[0,0,0,1]);sx,sy,sz=n.get('scale',[1,1,1]);tx,ty,tz=n.get('translation',[0,0,0])
    return [(1-2*(y*y+z*z))*sx,2*(x*y+z*w)*sx,2*(x*z-y*w)*sx,0,
            2*(x*y-z*w)*sy,(1-2*(x*x+z*z))*sy,2*(y*z+x*w)*sy,0,
            2*(x*z+y*w)*sz,2*(y*z-x*w)*sz,(1-2*(x*x+y*y))*sz,0,tx,ty,tz,1]

def determinant4(m):
    a=[[m[c*4+r] for c in range(4)] for r in range(4)]; d=1.0
    for i in range(4):
        pivot=max(range(i,4), key=lambda r:abs(a[r][i]))
        if abs(a[pivot][i])<1e-15:return 0.0
        if pivot!=i:a[i],a[pivot]=a[pivot],a[i];d=-d
        d*=a[i][i]
        for r in range(i+1,4):
            factor=a[r][i]/a[i][i]
            for c in range(i+1,4):a[r][c]-=factor*a[i][c]
    return d

def image_size(raw):
    if raw[:8] == b'\x89PNG\r\n\x1a\n': return list(struct.unpack_from('>II',raw,16))
    if raw[:2] == b'\xff\xd8':
        offset=2
        while offset<len(raw)-9:
            if raw[offset]!=255:offset+=1;continue
            marker=raw[offset+1];offset+=2
            if marker in [0xd8,0xd9]:continue
            length=struct.unpack_from('>H',raw,offset)[0]
            if marker in [0xc0,0xc1,0xc2,0xc3]:
                height,width=struct.unpack_from('>HH',raw,offset+3);return [width,height]
            offset+=length
    return None

def audit(path):
    data=Path(path).read_bytes(); chunks=[];offset=12
    while offset<len(data):
        length,kind=struct.unpack_from('<II',data,offset);chunks.append((kind,data[offset+8:offset+8+length]));offset+=8+length
    d=json.loads(next(b for k,b in chunks if k==0x4e4f534a));blob=next(b for k,b in chunks if k==0x004e4942)
    def accessor(i):
        a=d['accessors'][i];v=d['bufferViews'][a['bufferView']];fmt,size=COMPONENT[a['componentType']];width=WIDTH[a['type']]
        stride=v.get('byteStride',size*width);start=v.get('byteOffset',0)+a.get('byteOffset',0)
        rows=[list(struct.unpack_from('<'+fmt*width,blob,start+j*stride)) for j in range(a['count'])]
        if a.get('normalized'):
            maximum={5120:127,5121:255,5122:32767,5123:65535}.get(a['componentType'])
            if maximum: rows=[[max(-1,x/maximum) for x in row] for row in rows]
        return rows
    parents={c:i for i,n in enumerate(d['nodes']) for c in n.get('children',[])};cache={}
    def world(i):
        if i not in cache:cache[i]=multiply(world(parents[i]),matrix(d['nodes'][i])) if i in parents else matrix(d['nodes'][i])
        return cache[i]
    allpoints=[];primitives=[];sums=[];badweights=0;unweighted=0;invalidjoints=0;finite=True
    for ni,node in enumerate(d['nodes']):
        if 'mesh' not in node:continue
        transform=world(ni)
        joint_count=len(d.get('skins',[])[node['skin']]['joints']) if 'skin' in node else 0
        for p in d['meshes'][node['mesh']]['primitives']:
            attrs=p['attributes'];pts=accessor(attrs['POSITION']);finite=finite and all(math.isfinite(x) for row in pts for x in row)
            for x,y,z in pts:allpoints.append([transform[r]*x+transform[4+r]*y+transform[8+r]*z+transform[12+r] for r in range(3)])
            count=d['accessors'][p['indices']]['count'] if 'indices' in p else len(pts)
            primitives.append({'vertices':len(pts),'indices':count,'triangles':count//3 if p.get('mode',4)==4 else None,'mode':p.get('mode',4),'attributes':list(attrs)})
            if 'WEIGHTS_0' in attrs:
                weights=accessor(attrs['WEIGHTS_0']);joints=accessor(attrs['JOINTS_0'])
                if 'WEIGHTS_1' in attrs:
                    extra=accessor(attrs['WEIGHTS_1']);weights=[a+b for a,b in zip(weights,extra)]
                for row,jrow in zip(weights,joints):
                    finite=finite and all(math.isfinite(x) for x in row)
                    sums.append(sum(row));unweighted+=sum(row)<1e-6;badweights+=sum(x<0 or x>1 for x in row)
                    invalidjoints+=sum(int(j)<0 or int(j)>=joint_count for j in jrow)
    bounds={'min':[min(p[i] for p in allpoints) for i in range(3)],'max':[max(p[i] for p in allpoints) for i in range(3)]}
    bounds['size']=[b-a for a,b in zip(bounds['min'],bounds['max'])]
    skins=[]
    for skin in d.get('skins',[]):
        ibm=accessor(skin['inverseBindMatrices']) if 'inverseBindMatrices' in skin else []
        det=[determinant4(m) for m in ibm]
        skins.append({'bones':len(skin['joints']),'bone_names':[d['nodes'][i].get('name','') for i in skin['joints']],
            'inverse_bind_count':len(ibm),'finite':all(math.isfinite(x) for m in ibm for x in m),'min_abs_determinant':min(map(abs,det)) if det else None})
    names={n.get('name','').replace('mixamorig:','').lower():i for i,n in enumerate(d['nodes'])}
    def joint(name):
        m=world(names[name]);return m[12:15]
    def direction(a,b):
        v=[x-y for x,y in zip(joint(a),joint(b))];length=math.sqrt(sum(x*x for x in v));return [x/length for x in v]
    anatomy={'up_neck_minus_hips':direction('neck','hips'),'left_foot_forward':direction('lefttoebase','leftfoot'),
        'right_foot_forward':direction('righttoebase','rightfoot')}
    up=anatomy['up_neck_minus_hips'];toe=[(x+y)*.5 for x,y in zip(anatomy['left_foot_forward'],anatomy['right_foot_forward'])]
    dot=sum(x*y for x,y in zip(up,toe));projected=[x-dot*y for x,y in zip(toe,up)];length=math.sqrt(sum(x*x for x in projected))
    anatomy['forward_projected_onto_body_plane']=[x/length for x in projected]
    image_report=[]
    for image in d.get('images',[]):
        view=d['bufferViews'][image['bufferView']];start=view.get('byteOffset',0);raw=blob[start:start+view['byteLength']]
        image_report.append({'mimeType':image.get('mimeType'),'embedded_bytes':view['byteLength'],'size':image_size(raw),'sha256':hashlib.sha256(raw).hexdigest(),'uri':image.get('uri')})
    return {'source':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'source_sha256_unchanged_after_inspection':hashlib.sha256(Path(path).read_bytes()).hexdigest()==hashlib.sha256(data).hexdigest(),'gltf_asset':d.get('asset'),
        'coordinate_convention':'glTF right-handed +Y up; +Z forward is asset-facing convention, confirmed separately by renders and toe bones',
        'scene_bounds':bounds,'vertices':sum(p['vertices'] for p in primitives),'triangles':sum(p['triangles'] or 0 for p in primitives),
        'primitives':primitives,'nodes':len(d['nodes']),'skins':skins,'morph_targets':sum(len(p.get('targets',[])) for m in d['meshes'] for p in m['primitives']),
        'animations':[{'name':a.get('name'),'channels':len(a.get('channels',[]))} for a in d.get('animations',[])],
        'weights':{'rows':len(sums),'sum_min':min(sums) if sums else None,'sum_max':max(sums) if sums else None,'max_abs_sum_error':max(abs(s-1) for s in sums) if sums else None,
            'outside_zero_one':badweights,'unweighted':unweighted,'invalid_joint_references':invalidjoints},
        'finite_geometry_and_weights':finite,'node_matrices_finite':all(math.isfinite(x) for n in d['nodes'] for x in matrix(n)),
        'anatomical_directions':anatomy,'materials':d.get('materials',[]),'images':image_report,
        'accessors_with_sparse':[i for i,a in enumerate(d['accessors']) if 'sparse'in a]}

if __name__=='__main__':
    root=Path(__file__).resolve().parent
    old=root.parents[3]/'.cache/rework/legacy-mio.glb'
    if not old.exists(): raise FileNotFoundError('Legacy cache is missing; follow the recovery instructions in this helper docstring.')
    if hashlib.sha256(old.read_bytes()).hexdigest()!='70a343c829f5e4b79802435bbd24365219cd24c5e4e38e197393aeaf9536b074': raise ValueError('Legacy source hash mismatch; refusing to relabel a candidate as OLD.')
    new=Path('/Users/hayatok/Downloads/cloudsea-mio-v2-rigged-source.glb')
    report={'old':audit(old),'new':audit(new)}
    report['old']['source_commit']='07c2730'
    report['old']['source_origin']='07c2730:2026-10-24-2/game/assets/models/mio.glb'
    report['old']['source_role']='Immutable legacy comparison input; current game path now contains the candidate.'
    game_model=root.parents[3]/'game/assets/models/mio.glb'
    report['new']['candidate_integration']={'game_path':str(game_model),'same_sha256':hashlib.sha256(game_model.read_bytes()).hexdigest()==report['new']['sha256'],'status':'Candidate integrated by parent after inspection; user aesthetic approval remains pending.'}
    old_b=set(report['old']['skins'][0]['bone_names']);new_b=set(report['new']['skins'][0]['bone_names'])
    report['bone_compatibility']={'exact_names_equal':old_b==new_b,'missing_from_new':sorted(old_b-new_b),'added':sorted(new_b-old_b)}
    (root/'raw-audit.json').write_text(json.dumps(report,indent=2))
    for key in ['old','new']:
        a=report[key];print(key,a['vertices'],a['triangles'],len(a['skins'][0]['bone_names']),a['scene_bounds'],a['weights'])
