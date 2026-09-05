"""Run with Blender --background --python scripts/create-assets.py. Z-up authoring, glTF Y-up export."""
import bpy, math, os, json, sys
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if os.path.exists(os.path.join(ROOT,'assets/source/cleaning-kit.blend')) and '--rebuild-base' not in sys.argv:
    raise RuntimeError('Reviewed source exists. Use export-assets.py to preserve GUI edits. --rebuild-base explicitly discards them.')
OUT=os.path.join(ROOT,'public','models'); os.makedirs(OUT,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version=0
colors={'ink':'292d31','cream':'f5eddc','orange':'ed713b','purple':'9282ae','mint':'68bcb1','box':'bb9271'}
mats={}
for key,h in colors.items():
    m=bpy.data.materials.new(key); m.diffuse_color=tuple(int(h[i:i+2],16)/255 for i in (0,2,4))+(1,);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=m.diffuse_color;bs.inputs['Roughness'].default_value=.85;mats[key]=m
models={}
def part(name,shape,loc,scale,color,rot=None):
    if shape=='ball': bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=loc)
    elif shape=='ico': bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,location=loc)
    elif shape=='cyl': bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=1,depth=2,location=loc)
    else: bpy.ops.mesh.primitive_cube_add(size=2,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mats[color])
    if rot:o.rotation_euler=rot
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if shape=='cube':
        mod=o.modifiers.new('toy_edges','BEVEL');mod.width=.055;mod.segments=1;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
current=[]
def p(*args,**kwargs):
    o=part(*args,**kwargs);current.append(o);return o
def start():current.clear()
def finish(name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in current:o.select_set(True)
    root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
    for o in current:o.parent=root
    root.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
    models[name]=root

def eyes(y,z,width=.22):
    for x in [-width,width]:
        p('eye','ball',(x,y,z),(.135,.075,.17),'cream');p('pupil','ball',(x,y-.065,z),(.065,.035,.095),'ink')
start()
p('bumper','cyl',(0,0,.32),(.8,.72,.18),'ink');p('body','cyl',(0,0,.57),(.7,.64,.24),'cream');p('cap','cyl',(0,0,.83),(.53,.5,.075),'orange')
p('visor','cube',(0,-.57,.61),(.46,.1,.17),'ink');eyes(-.69,.64)
for x in [-.76,.76]:p('wheel','cyl',(x,0,.28),(.24,.24,.12),'ink',(0,math.pi/2,0))
p('antenna','cyl',(.25,.2,1.02),(.035,.035,.16),'ink');p('antenna_tip','ball',(.25,.2,1.19),(.09,.09,.09),'mint');finish('robot')
for kind in ['dust','dash','box','boss']:
    start();s=2.1 if kind=='boss' else 1
    if kind=='box':
        p('carton','cube',(0,0,.6),(.54,.47,.58),'box');p('tape','cube',(0,0,1.2),(.1,.49,.025),'cream');eyes(-.48,.64)
    else:
        p('fluff','ico',(0,0,.56*s),(.62*s,.5*s,.53*s),'purple')
        for i in range(6):
            a=i*math.tau/6;p('tuft','ico',(math.cos(a)*.45*s,math.sin(a)*.35*s,.65*s),(.28*s,.27*s,.29*s),'purple')
        eyes(-.49*s,.65*s,.23*s)
        if kind=='dash':p('tail','ico',(0,.66,.55),(.21,.6,.18),'cream')
        if kind=='boss':
            for x in [-.65,0,.65]:p('crown','cube',(x,.1,1.85),(.14,.2,.42),'orange', (0, x*.35,0))
    finish(kind)
start();p('neck','cyl',(0,0,.25),(.12,.12,.3),'orange',(math.pi/2,0,0));p('head','cube',(0,-.35,.2),(.45,.22,.17),'ink');p('mouth','cube',(0,-.56,.22),(.34,.02,.085),'mint');finish('nozzle')
start();p('handle','cyl',(0,0,.52),(.055,.055,.5),'orange');p('brush','cube',(0,0,.1),(.38,.22,.09),'ink')
for i in range(5):p('bristles','cube',((i-2)*.145,0,.06),(.055,.27,.035),'mint')
finish('mop')
start();p('bottle','cyl',(0,0,.32),(.16,.16,.28),'mint');p('trigger','cube',(0,-.1,.66),(.16,.2,.07),'orange');finish('spray')
start();p('disc','cyl',(0,0,.14),(.36,.36,.075),'orange');p('hub','cyl',(0,0,.23),(.15,.15,.04),'cream');finish('disc')
for name,color in [('battery','mint'),('heal','orange')]:
    start();p('cell','cube',(0,0,.2),(.14,.12,.2),color);p('tip','cube',(0,0,.43),(.07,.07,.03),'ink');p('stripe','cube',(0,-.125,.2),(.075,.012,.025),'cream');finish(name)
start();p('floor','cube',(0,0,-.09),(1.97,1.97,.08),'cream');finish('tile')
start()
for x in [-.7,0,.7]:p('plank','cube',(x,0,.16),(.29,.8,.075),'box')
for y in [-.5,.5]:p('foot','cube',(0,y,.07),(.9,.09,.06),'ink')
finish('pallet')
start();p('box','cube',(0,0,.45),(.5,.5,.45),'box');p('tape','cube',(0,0,.91),(.1,.5,.02),'cream');finish('crate')
start()
for x in [-1.8,1.8]:p('post','cube',(x,0,.35),(.08,.08,.35),'ink')
p('rail','cube',(0,0,.65),(2,.06,.08),'orange');finish('fence')
# Save an inspectable source library laid out on a grid. Exported assets remain at origin.
for i,(name,root) in enumerate(models.items()):root.location=((i%5)*4,(i//5)*4,0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'assets','source','cleaning-kit.blend'))
manifest={name:{'file':name+'.glb','bytes':os.path.getsize(os.path.join(OUT,name+'.glb')),'triangles':sum(len(o.data.polygons) for o in root.children if o.type=='MESH')} for name,root in models.items()}
with open(os.path.join(OUT,'manifest.json'),'w') as f:json.dump({'generator':'Blender '+bpy.app.version_string,'assets':manifest},f,indent=2)
print('ASSETS_COMPLETE',len(models))
