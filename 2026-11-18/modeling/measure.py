"""Measure geometry and planted soles on the GLBs after a fresh import."""
import bpy, json, sys
from pathlib import Path
from mathutils import Vector
here=Path(__file__).resolve().parent
out=here/'review';out.mkdir(exist_ok=True)
rows=[]
for i in range(1,7):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    file=here.parent/'game'/'racers'/f'{i:02}.glb'
    bpy.ops.import_scene.gltf(filepath=str(file))
    mesh=next(o for o in scene.objects if o.type=='MESH')
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
    points=[ev.matrix_world@v.co for v in ev.data.vertices]
    bounds=[[round(min(p[j] for p in points),4) for j in range(3)],[round(max(p[j] for p in points),4) for j in range(3)]]
    mesh.data.calc_loop_triangles()
    row={'bib':i,'height_m':round(bounds[1][2]-bounds[0][2],4),'bounds_blender_xyz_m':bounds,'triangles':len(mesh.data.loop_triangles),'glb_bytes':file.stat().st_size,'bones':len(arm.data.bones),'surfaces':len(mesh.material_slots),'clips':list(tracks)}
    if i==1:
        gi=mesh.vertex_groups['Foot.L'].index
        ids=[v.index for v in mesh.data.vertices if any(g.group==gi and g.weight>.99 for g in v.groups)]
        row['left_sole_support_Y_up_m']={}
        for state,fractions in [('run',[0,.05,.10,.15,.20,.25,.28]),('land',[0,.25,.50,.75,1])]:
            arr=[]
            for frac in fractions:
                ev=pose(state,frac)
                arr.append([frac,round(min((ev.matrix_world@ev.data.vertices[j].co).z for j in ids),4)])
            row['left_sole_support_Y_up_m'][state]=arr
    rows.append(row)
(out/'measurements.json').write_text(json.dumps(rows,indent=2)+'\n')
