"""Reproducible low-poly cast and FPS weapon build. Run with Blender --background --python.
Dimensions inferred from market concept; rear surfaces and hidden mechanisms are original designs.
Rigid separated joints are animated by combat/enemy.gd; GLB uses Y up, facing -Z.
"""
import bpy, math, random, pathlib, json
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'game/combat/models'; OUT.mkdir(parents=True,exist_ok=True)
REVIEW=ROOT/'modeling/review'; REVIEW.mkdir(parents=True,exist_ok=True)
random.seed(918)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
materials={}
# Original pixel textures, encoded in exported GLB, nearest sampling.
def mat(name,color,metal=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.83; bs.inputs['Metallic'].default_value=metal
    im=bpy.data.images.new(name+'_pixels',32,32)
    pixels=[]
    for y in range(32):
        for x in range(32):
            n=random.choice([.65,.8,.92,1,1,1.08,1.16]); rust=random.random()<.055 and metal>0
            c=(.28,.105,.035) if rust else color
            pixels.extend([min(1,v*n) for v in c]+[1])
    im.pixels=pixels; im.pack()
    tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im; tex.interpolation='Closest'
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    materials[name]=m; return m
for name,c,metal in [('navy',(.055,.12,.16),0),('yellow',(.48,.32,.035),0),('skin',(.39,.43,.32),0),('bone',(.68,.65,.45),0),('rubber',(.035,.04,.035),0),('boots',(.57,.62,.53),0),('steel',(.16,.19,.18),.65),('brass',(.54,.32,.08),.65),('visor',(.025,.09,.075),.6),('blood',(.23,.025,.015),0),('red',(.54,.065,.025),.2),('wood',(.25,.095,.035),0),('orange',(.55,.17,.055),0),('teal',(.035,.25,.2),0),('ember',(1,.26,.015),0)]: mat(name,c,metal)
# Concept-sheet atlas panels are supplied/generated artwork, cropped without repainting.
source=bpy.data.images.load(str(ROOT/'art/cast.png')); source_pixels=list(source.pixels); sw,sh=source.size

def atlas_material(name,box):
    x,y,w,h=box; im=bpy.data.images.new(name+'_reference_crop',w,h)
    pixels=[]
    for row in range(h):
        source_y=sh-y-h+row
        start=(source_y*sw+x)*4; pixels.extend(source_pixels[start:start+w*4])
    im.pixels=pixels; im.pack()
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Roughness'].default_value=.9
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;tex.interpolation='Closest'
    m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);materials[name]=m
atlas_material('worker_face',(253,755,43,58))
atlas_material('runner_face',(623,755,43,54))
atlas_material('apron_print',(296,813,35,66))
atlas_material('navy_fabric',(255,824,38,45))
atlas_material('orange_fabric',(686,756,35,80))

# One portable atlas material: base color preserves face/decal UVs; small data maps
# preserve each source material's roughness/metal response and the ember emission.
ATLAS_COLS=5;ATLAS_ROWS=4;TILE=64;PAD=2
atlas_slots={name:i for i,name in enumerate(materials)}
base=bpy.data.images.new('combat_atlas_color',ATLAS_COLS*TILE,ATLAS_ROWS*TILE)
base_pixels=[0.0]*(ATLAS_COLS*TILE*ATLAS_ROWS*TILE*4)
data=bpy.data.images.new('combat_atlas_rough_metal',ATLAS_COLS*4,ATLAS_ROWS*4);data.colorspace_settings.name='Non-Color'
data_pixels=[0.0]*(ATLAS_COLS*4*ATLAS_ROWS*4*4)
emission=bpy.data.images.new('combat_atlas_emission',ATLAS_COLS*4,ATLAS_ROWS*4)
emission_pixels=[0.0]*(ATLAS_COLS*4*ATLAS_ROWS*4*4)
for name,index in atlas_slots.items():
    material=materials[name];bs=material.node_tree.nodes.get('Principled BSDF')
    source_tex=next(n for n in material.node_tree.nodes if n.type=='TEX_IMAGE').image
    iw,ih=source_tex.size;pixels=list(source_tex.pixels);column=index%ATLAS_COLS;row=index//ATLAS_COLS
    for y in range(TILE):
        sy=round(max(0,min(1,(y-PAD)/(TILE-PAD*2-1)))*(ih-1))
        for x in range(TILE):
            sx=round(max(0,min(1,(x-PAD)/(TILE-PAD*2-1)))*(iw-1))
            target=((row*TILE+y)*(ATLAS_COLS*TILE)+column*TILE+x)*4
            base_pixels[target:target+4]=pixels[(sy*iw+sx)*4:(sy*iw+sx)*4+4]
    for y in range(4):
        for x in range(4):
            target=((row*4+y)*(ATLAS_COLS*4)+column*4+x)*4
            data_pixels[target:target+4]=[1,bs.inputs['Roughness'].default_value,bs.inputs['Metallic'].default_value,1]
            emission_pixels[target:target+4]=[1,.15,.005,1] if name=='ember' else [0,0,0,1]
base.pixels=base_pixels;data.pixels=data_pixels;emission.pixels=emission_pixels
for im in [base,data,emission]:im.pack()
atlas=bpy.data.materials.new('COMBAT_ATLAS');atlas.use_nodes=True
bs=atlas.node_tree.nodes.get('Principled BSDF')
def atlas_tex(im):
    node=atlas.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;node.interpolation='Closest';return node
atlas.node_tree.links.new(atlas_tex(base).outputs['Color'],bs.inputs['Base Color'])
separate=atlas.node_tree.nodes.new('ShaderNodeSeparateColor')
atlas.node_tree.links.new(atlas_tex(data).outputs['Color'],separate.inputs['Color'])
atlas.node_tree.links.new(separate.outputs['Green'],bs.inputs['Roughness'])
atlas.node_tree.links.new(separate.outputs['Blue'],bs.inputs['Metallic'])
atlas.node_tree.links.new(atlas_tex(emission).outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.65

def atlas_mesh(obj):
    mesh=obj.data;uv=mesh.uv_layers.active
    for poly in mesh.polygons:
        name=mesh.materials[poly.material_index].name;index=atlas_slots[name]
        column=index%ATLAS_COLS;row=index//ATLAS_COLS
        for loop in poly.loop_indices:
            u,v=uv.data[loop].uv
            u=max(0,min(1,u));v=max(0,min(1,v))
            uv.data[loop].uv=((column+(PAD+u*(TILE-PAD*2))/TILE)/ATLAS_COLS,(row+(PAD+v*(TILE-PAD*2))/TILE)/ATLAS_ROWS)
        poly.material_index=0
    mesh.materials.clear();mesh.materials.append(atlas)

def face_surface(parent,kind):
    verts=[];uvs=[]
    for row,(z,width,y) in enumerate([(-.23,.105,-.12),(-.11,.155,-.175),(.07,.18,-.17),(.22,.165,-.10)]):
        for column in range(3):
            verts.append(((column-1)*width,y-(.035 if column==1 else 0),z))
            uvs.append((column*.5,row/3))
    faces=[]
    for row in range(3):
        for col in range(2):
            a=row*3+col;faces.append((a,a+1,a+4,a+3))
    mesh=bpy.data.meshes.new('sculpted_face');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('face_surface',mesh);bpy.context.collection.objects.link(obj);obj.parent=parent
    mesh.materials.append(materials['worker_face' if kind==0 else 'runner_face'])
    layer=mesh.uv_layers.new()
    for poly in mesh.polygons:
        for loop in poly.loop_indices:layer.data[loop].uv=uvs[mesh.loops[loop].vertex_index]

def empty(name,pos,parent=None):
    o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o); o.location=pos
    if parent:o.parent=parent
    return o
def cube(name,loc,scale,material,parent=None,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('edge_facets','BEVEL'); mod.width=bevel; mod.segments=1
        bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    # Clothing volumes taper; asymmetry breaks the block silhouette without subpixel detail.
    if any(token in name for token in ['coat','sleeve','trouser']):
        for v in o.data.vertices:
            ratio=(v.co.z/max(scale[2],.01))+.5
            v.co.x *= .82+.18*ratio
            v.co.y *= .86+.14*ratio
            if 'coat' in name and v.co.z<0: v.co.z += .025*math.sin(v.co.x*23)
    o.data.materials.append(materials[material])
    if material in ['navy_fabric','orange_fabric','apron_print']:
        layer=o.data.uv_layers.active
        for poly in o.data.polygons:
            axes=(0,2) if abs(poly.normal.y)>.5 else ((1,2) if abs(poly.normal.x)>.5 else (0,1))
            for loop in poly.loop_indices:
                co=o.data.vertices[o.data.loops[loop].vertex_index].co
                layer.data[loop].uv=(co[axes[0]]/scale[axes[0]]+.5,co[axes[1]]/scale[axes[1]]+.5)
    if parent:o.parent=parent
    return o
def sphere(name,loc,scale,material,parent=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc); o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(materials[material]);
    if parent:o.parent=parent
    # ico sphere UVs
    bpy.context.view_layer.objects.active=o; bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.smart_project(); bpy.ops.object.mode_set(mode='OBJECT')
    return o
def cyl(name,loc,radius,depth,material,parent=None,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=radius,depth=depth,location=loc,rotation=rotation); o=bpy.context.object; o.name=name
    o.data.materials.append(materials[material]);
    if parent:o.parent=parent
    return o
def export(name,root):
    # Batch fixed geometry under each animated pivot; retain ammunition as moving parts.
    groups={}
    for obj in list(root.children_recursive):
        if obj.type=='MESH' and not obj.name.startswith('belt_round'):
            groups.setdefault(obj.parent,[]).append(obj)
    for pivot,objects in groups.items():
        if len(objects)<2:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
        objects[0].name=pivot.name+'_batched'
    for obj in root.children_recursive:
        if obj.type=='MESH':atlas_mesh(obj)
    wrapper=empty(name+'_asset',(0,0,0))
    root.parent=wrapper
    root=wrapper
    bpy.ops.object.select_all(action='DESELECT'); root.select_set(True)
    descendants=list(root.children_recursive)
    for obj in descendants:obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    for obj in [root]+descendants:obj.hide_render=True
    return len([o for o in descendants if o.type=='MESH'])
counts={}
for k in range(4):
    root=empty('enemy_'+str(k),(0,0,0))
    bulk=[1, .83,1.4,1.5][k]; height=[1, .9,1.21,1.25][k]; garment=['navy_fabric','orange_fabric','yellow','navy_fabric'][k]
    torso=empty('Torso',(0,0,1.13*height),root)
    torso.rotation_euler.x=.2 if k==1 else .075
    body=cube('coat', (0,0,.12*height),(.57*bulk,.34*bulk,.63*height),garment,torso,.07)
    cube('apron',(0,-.19*bulk,-.1),(.42*bulk,.035,.63*height),'rubber' if k==2 else ('apron_print' if k==0 else garment),torso,.01)
    for x in [-.16,.16]:cube('lapel',(x*bulk,-.19*bulk,.38),(.12,.04,.29),garment,torso,.02).rotation_euler.y=x
    cube('chest_seam',(0,-.208*bulk,.18),(.025,.015,.43),'rubber',torso)
    cube('blood_on_coat',(.16,-.213*bulk,.02),(.14,.018,.22),'blood',torso)
    for s,label in [(-1,'L'),(1,'R')]:
        leg=empty('Leg'+label,(s*.18*bulk,0,.9*height),root)
        cube('trouser'+label,(0,.01,-.2*height),(.22*bulk,.25,.43*height),garment,leg,.035)
        knee=empty('Knee'+label,(0,0,-.4*height),leg)
        cube('bootshaft'+label,(0,0,-.17*height),(.23*bulk,.26,.38*height),'boots' if k!=2 else 'rubber',knee,.025)
        cube('boottoe'+label,(0,-.09,-.41*height),(.25*bulk,.43,.17),'boots' if k!=2 else 'steel',knee,.025)
        arm=empty('Arm'+label,(s*.36*bulk,0,1.48*height),root)
        arm.rotation_euler.y=s*.12
        arm.rotation_euler.x=.12 if s<0 else -.18
        cube('upper_sleeve'+label,(s*.055,0,-.22),(.24*bulk,.28,.46),garment,arm,.04)
        cube('lower_sleeve'+label,(s*.09,-.09,-.51),(.19*bulk,.22,.28),garment,arm,.025)
        hand=sphere('hand'+label,(s*.09,-.12,-.73),(.12,.09,.17),'skin',arm)
        for f in range(4):cube('finger'+label+str(f),(s*.09+(f-1.5)*.042,-.16,-.87),(.035,.055,.18),'skin',arm,.009)
    head=empty('Head',(0,-.23 if k==1 else -.12,1.72*height),root)
    head.rotation_euler.y=.08 if k==0 else -.06
    if k==2:
        sphere('diving_helmet',(0,0,0),(.34,.29,.34),'brass',head)
        for angle in range(0,360,60):
            a=math.radians(angle)
            sphere('helmet_bolt',(math.sin(a)*.24,-.23,math.cos(a)*.24),(.035,.035,.035),'brass',head)
        for x in [-.25,.25]:
            cube('diver_harness',(x,-.27,1.4),(.09,.06,.65),'rubber',root)
            cube('harness_buckle',(x,-.31,1.25),(.13,.03,.13),'brass',root)
        cyl('helmet_port',(0,-.265,0),.18,.075,'brass',head,(math.pi/2,0,0))
        cyl('glass',(0,-.31,0),.14,.018,'visor',head,(math.pi/2,0,0))
        for x in [-.075,0,.075]:cube('visor_grille',(x,-.328,0),(.015,.018,.23),'brass',head)
        cyl('neck_seal',(0,0,-.23),.28,.12,'steel',head)
        for x in [-.21,.21]:cyl('air_tank',(x,.3,1.28*height),.12,.66,'brass',root)
    else:
        sphere('skull',(0,.03,0),(.19,.14,.24),'skin',head)
        if k<2:
            face_surface(head,k)
        else:
            cube('jaw',(0,-.04,-.18),(.23,.18,.15),'skin',head,.03)
            for x in [-.085,.085]:
                cube('eye_socket',(x,-.149,.035),(.085,.045,.07),'rubber',head)
                cube('eye',(x,-.174,.03),(.034,.012,.025),'yellow',head)
            sphere('nose',(0,-.18,-.025),(.042,.05,.07),'skin',head)
            cube('mouth',(0,-.145,-.12),(.14,.045,.09),'rubber',head)
            for x in [-.05,0,.05]:cube('teeth',(x,-.17,-.1),(.028,.015,.025),'bone',head)
        if k==0:
            cube('worker_cap',(0,.025,.22),(.4,.32,.13),'boots',head,.04)
            cube('cap_brim',(0,-.13,.175),(.42,.22,.035),'boots',head)
        if k==1:
            cube('hood_top',(0,.04,.19),(.41,.31,.13),'orange',head,.04)
            for x in [-.205,.205]:cube('hood_side',(x,.05,-.01),(.075,.28,.37),'orange',head,.03)
        if k==3:
            cube('captain_crown',(0,.01,.24),(.46,.34,.17),'navy',head,.04)
            cube('captain_brim',(0,-.14,.15),(.48,.25,.04),'rubber',head)
            cube('badge',(0,-.177,.25),(.08,.02,.07),'brass',head)
            for x in [-.34,.34]:cube('epaulette',(x,0,1.57*height),(.23,.3,.07),'brass',root)
            cube('belt',(0,-.02,1.03*height),(.82,.51,.1),'rubber',root)
            cube('belt_buckle',(0,-.29,1.03*height),(.12,.035,.11),'brass',root)
    # Silhouette details from cast reference: apron straps, ragged coat, chain and shoulder wound.
    if k==0:
        for x in [-.17,.17]:
            cube('apron_strap',(x,-.215,1.43),(.055,.025,.42),'teal',root)
            cube('strap_buckle',(x,-.235,1.29),(.075,.02,.07),'brass',root)
    if k==3:
        for i in range(7):
            t=i/6
            bpy.ops.mesh.primitive_torus_add(major_segments=8,minor_segments=4,location=(.68+t*.65,-.1,.8*(1-t)+.12),major_radius=.105,minor_radius=.035,rotation=(math.pi/2 if i%2 else 0,0,0))
            link=bpy.context.object; link.name='chain_link'; link.data.materials.append(materials['steel'])
            chain_arm=next(child for child in root.children if child.name.startswith('ArmR'))
            link.location -= chain_arm.location; link.parent=chain_arm
        for x in [-.3,-.12,.12,.3]:
            shard=cube('coat_tail',(x,.04,.74),(.2,.34,.42),'navy',root,.025); shard.rotation_euler.y=x*.8
        sphere('shoulder_wound',(.43,-.04,1.97),(.27,.22,.15),'blood',root)
        for i in range(5):sphere('ember',(.32+random.random()*.23,-.16,1.96+random.random()*.09),(.055,.04,.045),'ember',root)
    # Flip the local mesh frame to Godot -Z, retaining an unrotated animation wrapper.
    root.rotation_euler.z=math.pi
    counts['enemy_'+str(k)]=export('enemy_'+str(k),root)
# FPS weapon axis Blender +Y toward shooter? Blender -Y maps Godot -Z? glTF maps Blender Y -> -Z; use +Y forward.
for k in range(3):
    root=empty('weapon_'+str(k),(0,0,0))
    if k==0:
        cube('receiver',(0,.2,0),(.19,.58,.16),'steel',root,.025)
        cube('feed_cover',(0,.19,.12),(.18,.42,.035),'steel',root,.012)
        cyl('barrel',(0,.76,.035),.045,.66,'steel',root,(math.pi/2,0,0))
        cyl('barrel_jacket',(0,.57,.035),.075,.32,'steel',root,(math.pi/2,0,0))
        for y in [.48,.56,.64]:
            for x in [-.071,.071]:cube('cooling_slot',(x,y,.04),(.01,.04,.055),'rubber',root)
        cube('box_mag',(-.10,.18,-.15),(.16,.28,.2),'steel',root,.025)
        for i in range(8):
            y=.13-i*.035; z=.05-i*.04
            cyl('belt_round'+str(i),(-.16,y,z),.014,.105,'brass',root,(0,math.pi/2,0))
            cube('belt_link'+str(i),(-.17,y,z),(.023,.027,.035),'steel',root)
        cube('stock',(0,-.24,-.03),(.10,.25,.13),'rubber',root,.02)
    elif k==1:
        for x in [-.058,.058]:
            cyl('double_barrel',(x,.5,.025),.052,.8,'steel',root,(math.pi/2,0,0))
            cyl('bore',(x,.907,.025),.038,.012,'rubber',root,(math.pi/2,0,0))
        cube('breech',(0,.075,.025),(.21,.21,.14),'steel',root,.015)
        cube('foregrip',(0,.35,-.075),(.17,.35,.11),'wood',root,.025)
        cube('stock',(0,-.22,-.06),(.14,.4,.18),'wood',root,.03)
        cyl('shell_left',(-.14,.04,.03),.026,.12,'red',root,(math.pi/2,0,0))
    else:
        cyl('flare_barrel',(0,.28,.025),.09,.44,'red',root,(math.pi/2,0,0))
        cyl('flare_muzzle',(0,.51,.025),.1,.07,'steel',root,(math.pi/2,0,0))
        cyl('flare_bore',(0,.551,.025),.074,.012,'rubber',root,(math.pi/2,0,0))
        cube('flare_frame',(0,.045,0),(.15,.16,.18),'steel',root,.02)
        cube('hinge',(0,.13,-.07),(.2,.08,.06),'brass',root,.01)
    for sx in [-.045,.045]:cube('rear_sight',(sx,.02,.145),(.022,.035,.065),'steel',root)
    cube('ejection_port',(.101,.18,.04),(.008,.14,.065),'rubber',root)
    cube('charging_handle',(.14,.1,.04),(.08,.035,.025),'steel',root)
    cube('front_sight',(0,.68 if k<2 else .4,.13),(.024,.04,.06),'steel',root)
    cube('grip',(0,-.02,-.18),(.115,.14,.25),'rubber',root,.02).rotation_euler.x=-.2
    # Clearly visible gloved shooting hand and support hand, cuff and sleeve.
    for x,y,z in [(.075,-.03,-.18),(-.13,.36,-.12)]:
        sphere('gloved_palm',(x,y,z),(.105,.15,.095),'rubber',root)
        for f in range(4):cube('glove_finger',(x+.06,y+(f-1.5)*.05,z+.035),(.1,.043,.065),'rubber',root,.012)
        cube('cuff',(x,y-.13,z-.07),(.17,.13,.14),'navy',root,.02)
        cube('forearm',(x,y-.28,z-.13),(.18,.25,.2),'navy',root,.025)
    counts['weapon_'+str(k)]=export('weapon_'+str(k),root)
# Save authoring source and render a lineup showing the actual meshes.
for o in bpy.data.objects:
    o.hide_render=False
for i in range(4):bpy.data.objects['enemy_'+str(i)+'_asset'].location.x=(i-1.5)*1.8
for i in range(3):
    w=bpy.data.objects['weapon_'+str(i)]; w.location=(i*1.4-1.4,2.7,.65); w.rotation_euler.z=.35
cube('review_ground',(0,0,-.1),(12,8,.15),'rubber')
bpy.ops.object.camera_add(location=(6,10,5)); camera=bpy.context.object
camera.rotation_euler=(Vector((0,-.2,1))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=9
bpy.context.scene.camera=camera
for loc,power,size in [((2,5,7),1800,7),((-5,1,5),1300,5)]:
    bpy.ops.object.light_add(type='AREA',location=loc); light=bpy.context.object; light.data.energy=power; light.data.shape='DISK'; light.data.size=size; light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.render.resolution_x=1400; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.world.color=(.13,.13,.13)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'modeling/combat_assets.blend'))
scene.render.filepath=str(REVIEW/'lineup.png'); bpy.ops.render.render(write_still=True)
(OUT/'manifest.json').write_text(json.dumps({'generator':'modeling/01_build_assets.py','units':'metres','front':'-Z in Godot','joint_animation':'runtime rigid limb pivots','texture':'original pixel wear plus cropped supplied cast atlas face/fabric panels','mesh_parts':counts,'materials':'one color/PBR/emission atlas material per mesh pivot','inferred':['rear costume','mechanisms','exact dimensions'],'reference':['art/market.png','art/cast.png','art/weapons.png']},indent=2))
