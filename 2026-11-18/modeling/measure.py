"""Measure geometry and planted soles on the GLBs after a fresh import."""
import bpy, json, sys
from math import radians,sin,cos
from pathlib import Path
from mathutils import Vector
here=Path(__file__).resolve().parent
sys.path.insert(0,str(here))
from face_paint import ink_uv
out=here/'review';out.mkdir(exist_ok=True)
def brow_visibility(facial,scene):
    """Ray-test area-weighted brow triangle centres through the complete Nagi model."""
    dep=bpy.context.evaluated_depsgraph_get()
    face=facial.evaluated_get(dep)
    mesh=face.data
    bx,by=ink_uv('brow')
    ids=set()
    for poly in mesh.polygons:
        uv=mesh.uv_layers.active.data[poly.loop_start].uv
        if abs(uv.x*1024-bx)<2 and abs((1-uv.y)*1024-by)<2:ids.add(poly.index)
    assert ids
    result=[]
    for yaw,pitch in ((0,0),(0,12),(0,23),(12,15),(-12,15),(23,15),(-23,15)):
        y,p=radians(yaw),radians(pitch)
        view=Vector((sin(y)*cos(p),cos(y)*cos(p),sin(p)))
        total=[0.,0.]; exposed=[0.,0.]
        for idx in ids:
            poly=mesh.polygons[idx]
            centre=face.matrix_world@poly.center
            side=int(centre.x>0)
            total[side]+=poly.area
            hit,point,normal,other,object_hit,matrix=scene.ray_cast(dep,centre+2*view,-view,distance=2.01)
            if hit and object_hit==facial and other in ids:exposed[side]+=poly.area
        result.append({'yaw_deg':yaw,'pitch_deg':pitch,
                       'visible_brow_area_fractions':[round(v/s,3) for v,s in zip(exposed,total)]})
    return result


rows=[]
for i in range(1,7):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    file=here.parent/'game'/'racers'/f'{i:02}.glb'
    bpy.ops.import_scene.gltf(filepath=str(file))
    mesh=next(o for o in scene.objects if o.name.endswith('_painted_mesh'))
    facial=next(o for o in scene.objects if o.name.startswith('FaceRig_'))
    arm=next(o for o in scene.objects if o.type=='ARMATURE')
    tracks={t.name:t for t in arm.animation_data.nla_tracks}
    for t in tracks.values():t.mute=True
    def pose(state,fraction):
        strip=tracks[state].strips[0];act=strip.action
        arm.animation_data.action=act
        if strip.action_slot:arm.animation_data.action_slot=strip.action_slot
        lo,hi=act.frame_range
        frame=lo+fraction*(hi-lo)
        scene.frame_set(int(frame),subframe=frame-int(frame))
        return mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    ev=pose('idle',0)
    face_ev=facial.evaluated_get(bpy.context.evaluated_depsgraph_get())
    points=[obj.matrix_world@v.co for obj in (ev,face_ev) for v in obj.data.vertices]
    bounds=[[round(min(p[j] for p in points),4) for j in range(3)],[round(max(p[j] for p in points),4) for j in range(3)]]
    for item in (mesh,facial):item.data.calc_loop_triangles()
    triangles=sum(len(item.data.loop_triangles) for item in (mesh,facial))
    row={'bib':i,'height_m':round(bounds[1][2]-bounds[0][2],4),'bounds_blender_xyz_m':bounds,'triangles':triangles,'body_triangles':len(mesh.data.loop_triangles),'face_triangles':len(facial.data.loop_triangles),'glb_bytes':file.stat().st_size,'bones':len(arm.data.bones),'surfaces':len(mesh.material_slots)+len(facial.material_slots),'material_count':len(set(mesh.data.materials)|set(facial.data.materials)),'expression_targets':[k.name for k in list(facial.data.shape_keys.key_blocks)[1:]],'clips':list(tracks)}
    # The reimported rig faces +Y in Blender. Measure the leading surface of
    # each hand against the actual head mesh and the lowest rigidly bound
    # surfaces at the three contact beats.
    groups={group.name:[] for group in mesh.vertex_groups}
    for vertex in mesh.data.vertices:
        weight=max(vertex.groups,key=lambda item:item.weight)
        groups[mesh.vertex_groups[weight.group].name].append(vertex.index)
    ev=pose('dive',.82)
    vertices=[ev.matrix_world@v.co for v in ev.data.vertices]
    face_ev=facial.evaluated_get(bpy.context.evaluated_depsgraph_get())
    face=max(max(vertices[j].y for j in groups['Head']),max((face_ev.matrix_world@v.co).y for v in face_ev.data.vertices))
    row['dive_reach_ahead_of_head_m']=[
        round(max(vertices[j].y for j in groups['Hand.'+side])-face,3) for side in ('L','R')]
    contacts={}
    for fraction in (0,.4,.88):
        ev=pose('slide',fraction)
        vertices=[ev.matrix_world@v.co for v in ev.data.vertices]
        floor,part=min((min(vertices[j].z for j in ids),name)
                       for name,ids in groups.items() if ids and name!='Blink')
        contacts[str(fraction)]={'lowest_part':part,'height_m':round(floor,4)}
    row['slide_contacts_at_normalized_phase']=contacts
    if i==1:
        pose('idle',0)
        row['brow_visibility_idle']=brow_visibility(facial,scene)
        gi=mesh.vertex_groups['Foot.L'].index
        ids=[v.index for v in mesh.data.vertices if any(g.group==gi and g.weight>.99 for g in v.groups)]
        row['left_sole_support_Y_up_m']={}
        for state,fractions in [('run',[0,.05,.10,.15,.20,.25,.28]),('land',[0,.25,.50,.75,1]),
                                ('sprint',[0,.05,.10,.15,.20,.25,.28,.50,.63])]:
            arr=[]
            for frac in fractions:
                ev=pose(state,frac)
                arr.append([frac,round(min((ev.matrix_world@ev.data.vertices[j].co).z for j in ids),4)])
            row['left_sole_support_Y_up_m'][state]=arr
    rows.append(row)
(out/'measurements.json').write_text(json.dumps(rows,indent=2)+'\n')
