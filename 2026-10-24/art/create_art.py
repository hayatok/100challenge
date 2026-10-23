"""TENSAI original procedural model source. Blender 5.2.1, no external assets.
Run: blender --background --python art/create_art.py
All character geometry is modeled from authored cross sections and weighted to a rig.
"""
import bpy, math, json, os
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
ART=ROOT/'art'; OUT=ROOT/'game/assets/models'
ART.mkdir(exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
FPS=30
bpy.context.preferences.filepaths.save_version=0
COLORS={'vermilion':(0.66,.055,.025,1),'redlight':(.92,.115,.045,1),'indigo':(.017,.027,.065,1),'navy':(.035,.065,.12,1),'ivory':(.82,.84,.79,1),'steel':(.24,.32,.38,1),'edge':(.72,.84,.87,1),'skin':(.64,.39,.27,1),'hair':(.025,.018,.035,1),'eye':(.03,.46,.65,1),'dark':(.008,.012,.018,1)}
M={}; parts=[]; rig=None

def mat(name):
    if name in M:return M[name]
    a=bpy.data.materials.new(name); a.diffuse_color=COLORS[name]; a.use_nodes=True
    bs=a.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=COLORS[name];bs.inputs['Roughness'].default_value=.68 if name not in ['steel','edge'] else .28
    bs.inputs['Metallic'].default_value=.75 if name in ['steel','edge'] else .05
    M[name]=a;return a

def mesh(name,verts,faces,color,bone=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);ob.data.materials.append(mat(color))
    if bone:
        vg=ob.vertex_groups.new(name=bone);vg.add(list(range(len(verts))),1,'REPLACE');mod=ob.modifiers.new('Deform','ARMATURE');mod.object=rig;ob.parent=rig;parts.append(ob)
    return ob

def loft(name,rings,color,bone,n=8):
    # rings: center x,y,z, horizontal radii x/y; diagonal facets create tailored planes
    verts=[]
    for x,y,z,rx,ry in rings:
        for j in range(n):
            a=2*math.pi*j/n+math.pi/8;verts.append((x+rx*math.cos(a),y+ry*math.sin(a),z))
    faces=[tuple(reversed(range(n)))];faces += [(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(rings)-1) for j in range(n)];faces.append(tuple((len(rings)-1)*n+j for j in range(n)))
    return mesh(name,verts,faces,color,bone)

def plate(name,outline,depth,color,bone):
    # outline x,y,z ordered in its panel plane; extrusion along Y
    vs=[(x,y+off,z) for off in [-depth/2,depth/2] for x,y,z in outline];n=len(outline)
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(j,(j+1)%n,(j+1)%n+n,j+n) for j in range(n)]
    return mesh(name,vs,fs,color,bone)

def ring(name,center,radius,width,color,bone,start=25,end=325):
    x,y,z=center;vs=[];steps=24
    for i in range(steps+1):
        a=math.radians(start+(end-start)*i/steps)
        for r,dy in [(radius-width/2,-width/2),(radius+width/2,-width/2),(radius+width/2,width/2),(radius-width/2,width/2)]:vs.append((x+r*math.cos(a),y+dy,z+r*math.sin(a)))
    fs=[]
    for i in range(steps):
        for j in range(4):fs.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
    fs.extend([(0,3,2,1),(steps*4,steps*4+1,steps*4+2,steps*4+3)])
    return mesh(name,vs,fs,color,bone)

def create_rig():
    global rig
    ar=bpy.data.armatures.new('TENSAI_skeleton');rig=bpy.data.objects.new('Rig',ar);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    bones=[('root',(0,0,0),(0,0,.16),None),('hips',(0,0,.92),(0,0,1.08),'root'),('spine',(0,0,1.08),(0,0,1.48),'hips'),('head',(0,0,1.48),(0,0,1.8),'spine')]
    for side,s in [('L',-1),('R',1)]:
        bones.extend([(f'thigh.{side}',(s*.115,0,.96),(s*.12,0,.53),'hips'),(f'shin.{side}',(s*.12,0,.53),(s*.12,0,.12),f'thigh.{side}'),(f'foot.{side}',(s*.12,0,.12),(s*.12,.18,.07),f'shin.{side}'),(f'upper_arm.{side}',(s*.24,0,1.42),(s*.37,0,1.15),'spine'),(f'forearm.{side}',(s*.37,0,1.15),(s*.43,.015,.91),f'upper_arm.{side}'),(f'hand.{side}',(s*.43,.015,.91),(s*.45,.02,.79),f'forearm.{side}'),(f'coat.{side}',(s*.11,-.07,1),(s*.19,-.1,.58),'hips')])
    for name,h,t,parent in bones:
        b=ar.edit_bones.new(name);b.head=h;b.tail=t
        if parent:b.parent=ar.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');rig.select_set(False)
    for b in rig.pose.bones:b.rotation_mode='XYZ'

def character(enemy=False):
    global parts,M
    parts=[];M={};create_rig()
    # Fitted silhouette: tapered boots, fitted navy trousers and jacket, asymmetrical armor.
    for side,s in [('L',-1),('R',1)]:
        x=s*.12
        loft('Boot_'+side,[(x,.065,.025,.088,.17),(x,.08,.10,.09,.16),(x,.005,.20,.065,.075),(x,0,.36,.075,.075)],'indigo',f'shin.{side}')
        plate('Boot_toe_plate_'+side,[(x-.064,.224,.045),(x+.064,.224,.045),(x+.055,.205,.105),(x-.055,.205,.105)],.025,'steel',f'shin.{side}')
        loft('Lower_leg_'+side,[(x,0,.25,.066,.067),(x,0,.50,.077,.077),(x,0,.56,.08,.076)],'navy',f'shin.{side}')
        loft('Trouser_'+side,[(x,0,.51,.077,.076),(x,0,.72,.09,.09),(x,0,.97,.10,.11)],'indigo',f'thigh.{side}')
        plate('Knee_'+side,[(x-.065,.079,.55),(x-.075,.085,.48),(x,.11,.44),(x+.075,.085,.48),(x+.065,.079,.55)],.035,'ivory' if enemy else 'steel',f'shin.{side}')
        loft('Sleeve_'+side,[(s*.25,0,1.46,.105,.115),(s*.32,0,1.31,.089,.09),(s*.37,0,1.17,.075,.08)],'indigo' if enemy else 'vermilion',f'upper_arm.{side}')
        loft('Forearm_'+side,[(s*.37,0,1.17,.075,.075),(s*.40,.01,1.03,.065,.066),(s*.43,.015,.91,.052,.06)],'navy',f'forearm.{side}')
        loft('Glove_'+side,[(s*.43,.015,.94,.059,.063),(s*.45,.025,.82,.058,.061),(s*.45,.03,.79,.044,.052)],'indigo',f'hand.{side}')
        # layered knuckle and cuff emphasize hand direction
        loft('Cuff_'+side,[(s*.416,.012,.98,.071,.078),(s*.425,.012,.94,.071,.078)],'steel',f'forearm.{side}')
    loft('Pelvis',[(0,0,.88,.18,.12),(0,0,1.05,.18,.13)],'indigo','hips')
    loft('Tailored_jacket',[(0,0,1.00,.185,.13),(0,0,1.15,.163,.12),(0,0,1.37,.245,.145),(0,0,1.47,.205,.12)],'indigo' if enemy else 'vermilion','spine')
    # Distinct center seam, front lapels, and belt shape are authored polygon panels.
    plate('Chest_bib',[(-.17,.126,1.39),(0,.16,1.24),(.17,.126,1.39),(.12,.13,1.47),(-.12,.13,1.47)],.012,'ivory' if enemy else 'indigo','spine')
    plate('Lapel_L',[(-.195,.10,1.45),(-.09,.155,1.45),(-.025,.16,1.16),(-.10,.155,1.25)],.016,'steel' if enemy else 'redlight','spine')
    plate('Lapel_R',[(.195,.10,1.45),(.09,.155,1.45),(.025,.16,1.16),(.10,.155,1.25)],.016,'steel' if enemy else 'redlight','spine')
    loft('Belt',[(0,0,1.015,.195,.145),(0,0,1.075,.186,.14)],'dark','hips')
    plate('Belt_clasp',[(-.04,.153,1.025),(.035,.153,1.025),(.05,.153,1.05),(.025,.153,1.077),(-.04,.153,1.077)],.025,'steel','hips')
    loft('Collar',[(0,0,1.43,.115,.092),(0,0,1.52,.108,.09)],'indigo','spine')
    # Split flared rear coat panels, weighted to their own bones, clear of leg silhouette.
    for side,s in [('L',-1),('R',1)]:
        plate('Split_coat_'+side,[(s*.02,-.135,1.03),(s*.18,-.13,1.03),(s*.26,-.18,.66),(s*.14,-.21,.53),(s*.05,-.19,.62)],.035,'indigo' if enemy else 'vermilion',f'coat.{side}')
        plate('Coat_hem_'+side,[(s*.14,-.235,.53),(s*.26,-.205,.66),(s*.25,-.205,.70),(s*.13,-.235,.58)],.012,'steel' if enemy else 'redlight',f'coat.{side}')
    # Bone neck and angular head. Face planes rather than a blank sphere.
    loft('Neck',[(0,0,1.46,.063,.062),(0,0,1.57,.064,.067)],'dark' if enemy else 'skin','head')
    loft('Face',[(0,.012,1.53,.052,.055),(0,.025,1.57,.082,.075),(0,.02,1.68,.105,.087),(0,0,1.76,.09,.076)],'ivory' if enemy else 'skin','head',n=8)
    if enemy:
        # Split shell helmet has pronounced asymmetric crest and deep negative face slit.
        loft('Helmet_shell',[(0,-.025,1.60,.12,.09),(0,-.02,1.75,.135,.105),(0,-.03,1.84,.055,.065)],'ivory','head')
        plate('Face_recess',[(-.085,.102,1.74),(.085,.102,1.74),(.065,.107,1.64),(0,.117,1.59),(-.065,.107,1.64)],.018,'dark','head')
        plate('Visor',[(-.07,.12,1.70),(.07,.12,1.70),(.035,.13,1.684),(-.035,.13,1.684)],.012,'eye','head')
        plate('Crown_blade',[(-.027,-.02,1.76),(.018,-.02,1.98),(.07,-.02,1.89),(.06,-.02,1.74)],.075,'indigo','head')
        # Broader two shoulders and breast shells distinguish sentinel from hero.
        for side,s in [('L',-1),('R',1)]:
            plate('Shell_'+side,[(s*.19,.035,1.49),(s*.34,.035,1.51),(s*.41,.035,1.34),(s*.26,.035,1.30)],.25,'ivory',f'upper_arm.{side}')
        plate('Breast_shell',[(-.16,.16,1.37),(-.10,.17,1.18),(0,.18,1.13),(.10,.17,1.18),(.16,.16,1.37),(0,.19,1.30)],.035,'ivory','spine')
    else:
        loft('Hair_cap',[(0,-.01,1.66,.108,.09),(0,-.025,1.77,.11,.09),(0,-.03,1.82,.045,.045)],'hair','head')
        plate('Fringe',[(-.10,.079,1.76),(.095,.079,1.75),(.06,.10,1.67),(.015,.102,1.73),(-.05,.10,1.68)],.025,'hair','head')
        plate('Nose',[(-.012,.104,1.68),(.012,.104,1.68),(0,.136,1.636)],.01,'skin','head')
        for s in [-1,1]:
            plate('Eye',[(s*.027,.126,1.687),(s*.068,.112,1.69),(s*.063,.123,1.677),(s*.03,.134,1.677)],.008,'dark','head')
        plate('Mouth',[(-.028,.098,1.60),(.028,.098,1.60),(.015,.102,1.595),(-.015,.102,1.595)],.006,'hair','head')
        # White split-ring back crest reads from the gameplay camera.
        ring('Back_crest',(0,-.153,1.32),.083,.016,'ivory','spine',35,325)
        plate('Back_crest_slash',[(-.015,-.168,1.40),(.026,-.168,1.40),(.012,-.168,1.23),(-.026,-.168,1.25)],.009,'ivory','spine')
        # Short swept tied hair silhouette visible from the gameplay camera.
        plate('Hair_tie',[(-.065,-.08,1.74),(.065,-.08,1.74),(.10,-.13,1.58),(.03,-.15,1.52),(-.035,-.14,1.61)],.08,'hair','head')
        plate('Shoulder_shell_L',[(-.16,.035,1.49),(-.29,.035,1.51),(-.37,.035,1.40),(-.32,.035,1.31),(-.21,.035,1.34)],.25,'ivory','upper_arm.L')
        plate('Shoulder_inlay',[(-.20,.17,1.47),(-.285,.17,1.47),(-.335,.17,1.40),(-.30,.17,1.38)],.018,'steel','upper_arm.L')
        # Forearm wire launcher: split circular spool + barrel, deliberately not gold.
        ring('Wire_spool',(-.435,.08,1.085),.082,.026,'ivory','forearm.L',45,322)
        ring('Wire_spool_inner',(-.435,.085,1.085),.047,.012,'steel','forearm.L',45,322)
        plate('Launcher_housing',[(-.51,.055,1.16),(-.35,.055,1.16),(-.36,.055,.98),(-.47,.055,.97)],.09,'steel','forearm.L')
        plate('Launcher_slot',[(-.464,.11,1.14),(-.40,.11,1.14),(-.40,.11,1.11),(-.464,.11,1.11)],.01,'dark','forearm.L')
    # Sword authored as thin asymmetric blade with beveled central ridge. Entire sword shares hand weights.
    x=.45; y=.055; z=.82
    loft('Sword_grip',[(x,y,z+.07,.022,.026),(x,y,z-.075,.022,.026)],'dark','hand.R')
    ring('Broken_circle_guard',(x,y,z-.09),.087,.018,'steel','hand.R',20,310)
    vs=[(x-.045,y,z-.14),(x+.045,y,z-.14),(x+.043,y,z-.64),(x+.005,y,z-.83),(x-.029,y,z-.65),(x,y+.022,z-.14),(x,y+.019,z-.64),(x,y-.015,z-.14),(x,y-.012,z-.64)]
    fs=[(0,5,6,4),(5,1,2,6),(4,6,3),(6,2,3),(0,4,8,7),(7,8,2,1),(8,3,2),(4,3,8),(0,1,5),(0,7,1)]
    mesh('Single_edge_sword',vs,fs,'edge','hand.R')
    # Narrow dark fuller makes blade orientation apparent.
    plate('Blade_fuller',[(x-.015,y+.023,z-.17),(x-.005,y+.023,z-.17),(x-.005,y+.021,z-.58),(x-.015,y+.021,z-.64)],.002,'steel','hand.R')
    return rig

CLIPS={'idle':2.0,'run':.8,'slide':.8,'jump':.6,'fall':.8,'wire':.65,'slash_1':.55,'slash_2':.6,'slash_3':.75,'launch':.7,'plunge':.7,'hurt':.5,'death':1.2}
def animate():
    rig.animation_data_create()
    for name,dur in CLIPS.items():
        action=bpy.data.actions.new(name);rig.animation_data.action=action;end=round(dur*FPS)
        for f in range(1,end+1):
            t=(f-1)/(end-1);phase=2*math.pi*t;sin=math.sin(phase);strike=math.sin(math.pi*t);rot={};loc={}
            rot['upper_arm.L']=(.10,0,-.10);rot['upper_arm.R']=(.10,0,.12);rot['forearm.L']=(-.22,0,0);rot['forearm.R']=(-.22,0,0)
            rot['coat.L']=(-.08+sin*.035,0,-.04);rot['coat.R']=(-.08-sin*.035,0,.04)
            if name=='idle':rot['spine']=(.015*sin,0,.015*sin);loc['hips']=(0,0,.009*math.sin(phase))
            if name=='run':
                rot.update({'spine':(.19,0,.06*sin),'thigh.L':(.72*sin,0,0),'thigh.R':(-.72*sin,0,0),'shin.L':(-max(0,-sin)*1.1,0,0),'shin.R':(-max(0,sin)*1.1,0,0),'upper_arm.L':(-.55*sin,0,-.12),'upper_arm.R':(.45*sin,0,.15),'forearm.L':(-.7,0,0),'forearm.R':(-.7,0,0),'coat.L':(-.4-.15*sin,0,-.15),'coat.R':(-.4+.15*sin,0,.15)})
                loc['hips']=(0,0,.035*(1-math.cos(phase*2)))
            if name=='slide':rot.update({'hips':(.6,0,0),'thigh.L':(-1.1,0,-.2),'shin.L':(-.8,0,0),'thigh.R':(1.2,0,.15),'spine':(-.38,0,-.1),'upper_arm.L':(-.7,0,-.5),'upper_arm.R':(.55,0,.5),'coat.L':(-.8,0,0),'coat.R':(-.8,0,0)});loc['hips']=(0,0,-.4)
            if name in ['jump','fall','wire','plunge']:
                rot.update({'thigh.L':(-.6,0,-.1),'shin.L':(-.8,0,0),'thigh.R':(.5,0,.1),'shin.R':(-.5,0,0),'coat.L':(-.5,0,-.1),'coat.R':(-.6,0,.1)})
                if name=='jump':rot['spine']=(.15,0,0);rot['upper_arm.L']=(-.9*strike,0,-.2);rot['upper_arm.R']=(-.65*strike,0,.3)
                if name=='fall':rot['upper_arm.L']=(-.2,0,-.65);rot['upper_arm.R']=(-.2,0,.65)
                if name=='wire':rot['upper_arm.L']=(-1.5,0,-.15);rot['forearm.L']=(-.15,0,0);rot['spine']=(.22,0,-.2);rot['upper_arm.R']=(.4,0,.5)
                if name=='plunge':rot['spine']=(.65,0,0);rot['upper_arm.R']=(-.3,0,.15);rot['forearm.R']=(-.25,0,0);rot['upper_arm.L']=(.4,0,-.7)
            if name.startswith('slash') or name=='launch':
                sign=-1 if name=='slash_2' else 1
                # Anticipation -> impact -> followthrough, ending at a recoverable ready stance.
                swing=math.sin(math.pi*t)**.8
                rot['spine']=(.12*strike,0,sign*(-.40+1.0*t)*strike)
                rot['upper_arm.R']=(-1.0*swing,sign*.7*swing,sign*.95*math.sin(phase-.6)*strike)
                rot['forearm.R']=(-.85*swing,0,sign*.25*strike)
                rot['upper_arm.L']=(-.35*strike,0,-.6*strike)
                rot['thigh.L']=(-.2*strike,0,-.18*strike);rot['thigh.R']=(.25*strike,0,.15*strike)
                if name=='slash_3':rot['upper_arm.R']=(-2.35*swing,.15,1.0*math.sin(phase)*strike);rot['spine']=(.4*strike,0,.3*strike)
                if name=='launch':rot['upper_arm.R']=(-2.5*strike,0,-.2*strike);rot['spine']=(-.18*strike,0,-.25*strike)
                loc['hips']=(0,0,-.07*strike)
            if name=='hurt':rot['spine']=(-.35*strike,0,.2*strike);rot['head']=(.2*strike,0,0);rot['upper_arm.L']=(-.5*strike,0,-.35)
            if name=='death':
                eased=math.sin(t*math.pi/2);rot['root']=(1.45*eased,0,.12*eased);loc['root']=(0,-.35*eased,.11*eased)
                rot['thigh.L']=(-.35*eased,0,-.2*eased);rot['shin.L']=(-.6*eased,0,0);rot['upper_arm.R']=(-.3,0,.6*eased);rot['head']=(-.3*eased,0,0)
            for b in rig.pose.bones:
                angles=rot.get(b.name,(0,0,0))
                # Bone-local X points the opposite way from the pose sketch for arms and upright torso.
                if b.name.startswith(('upper_arm','forearm')) or b.name in ('spine','hips'):angles=(-angles[0],angles[1],angles[2])
                b.rotation_euler=angles;b.location=loc.get(b.name,(0,0,0));b.keyframe_insert('rotation_euler',frame=f,group=b.name);b.keyframe_insert('location',frame=f,group=b.name)
        track=rig.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,1,action);strip.name=name;track.mute=True
        action.use_fake_user=True
    rig.animation_data.action=None
    # Export tracks individually; retain no active action and unmute each NLA track.
    for tr in rig.animation_data.nla_tracks:tr.mute=False
    for b in rig.pose.bones:b.rotation_euler=(0,0,0);b.location=(0,0,0)

def setup_render():
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('StudioWorld');scene.world.color=(.15,.18,.23)
    bpy.ops.object.camera_add(location=(3.4,5.6,2.8));cam=bpy.context.object;cam.name='PreviewCamera';cam.rotation_euler=(Vector((0,0,.98))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.55;scene.camera=cam
    for loc,power,size in [((2,3,5),450,4),((-3,1,2),300,3),((1,-3,4),600,3)]:
        bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.rotation_euler=(Vector((0,0,1))-l.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012));floor=bpy.context.object;floor.name='Preview_ground';floor.data.materials.append(mat('navy'))
    scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'

stats={}
for kind in ['hero','sentinel']:
    bpy.ops.wm.read_factory_settings(use_empty=True);character(kind=='sentinel');animate()
    bpy.context.scene.render.fps=FPS
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
    for ob in parts:ob.select_set(True)
    # Export selected only so studio lighting never becomes a runtime dependency.
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True,export_force_sampling=True,export_frame_range=False,export_def_bones=True)
    stats[kind]={'vertices':sum(len(o.data.vertices) for o in parts),'polygons':sum(len(o.data.polygons) for o in parts),'mesh_parts':len(parts),'bones':list(rig.data.bones.keys()),'clips':CLIPS,'front':'Blender +Y / glTF -Z','height_m':max(v.co.z for o in parts for v in o.data.vertices)}
    # Preview static model with explicit designed ready pose, not a concept image.
    for tr in rig.animation_data.nla_tracks:tr.mute=True
    rig.pose.bones['upper_arm.R'].rotation_euler=(.12,0,.15);rig.pose.bones['forearm.R'].rotation_euler=(.25,0,0)
    rig.pose.bones['upper_arm.L'].rotation_euler=(.10,0,-.13)
    setup_render();bpy.context.scene.render.filepath=str(ART/(kind+'_preview.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/(kind+'.blend')))
    bpy.ops.render.render(write_still=True)
    if kind=='hero':
        cam=bpy.context.scene.camera;cam.location=(3.4,-5.6,2.8);cam.rotation_euler=(Vector((0,0,.98))-cam.location).to_track_quat('-Z','Y').to_euler()
        bpy.context.scene.render.filepath=str(ART/'hero_rear_preview.png');bpy.ops.render.render(write_still=True)
# Additional action evidence is rendered directly from the saved original.
(ART/'asset_metadata.json').write_text(json.dumps(stats,indent=2)+'\n')
