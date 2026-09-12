"""Editable miniature props and jointed original character. No level layout is generated."""
import bpy, math, os
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=ROOT+'/game/assets/models'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
M={}
def mat(n,c,rough=.5,metal=0):
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal; M[n]=m; return m
for n,c,r,me in [('coral',(.83,.16,.105),.32,0),('cream',(.96,.77,.42),.42,0),('ivory',(.98,.92,.74),.5,0),('ink',(.025,.045,.065),.27,0),('pink',(.97,.34,.29),.6,0),('mouth',(.055,.012,.015),.55,0),('teal',(.08,.46,.43),.4,0),('blue',(.17,.39,.53),.38,0),('mustard',(.97,.57,.10),.4,0),('steel',(.23,.31,.34),.4,.25),('rubber',(.035,.045,.05),.85,0),('glass',(.11,.25,.31),.17,.25),('white',(.95,.94,.83),.4,0),('core',(.33,.88,.68),.26,.12)]:mat(n,c,r,me)
collection=None
def begin(name):
 global collection
 collection=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(collection)
 return collection

def own(obj,name,parent=None):
 obj.name=name
 for c in list(obj.users_collection):c.objects.unlink(obj)
 collection.objects.link(obj)
 if parent:obj.parent=parent
 return obj

def joint(n,pos=(0,0,0),parent=None):
 o=bpy.data.objects.new(n,None); collection.objects.link(o); o.location=pos; o.parent=parent; return o

def ell(n,p,s,ma,parent=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=p)
 o=own(bpy.context.object,n,parent);o.scale=s
 o.data.materials.append(M[ma]);
 for f in o.data.polygons:f.use_smooth=True
 return o

def box(n,p,s,ma,parent=None,bevel=.07):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=own(bpy.context.object,n,parent);o.scale=s
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(M[ma])
 if bevel:
  mod=o.modifiers.new('Soft molded edges','BEVEL');mod.width=bevel;mod.segments=3
  mod=o.modifiers.new('Corner normals','WEIGHTED_NORMAL')
 return o

def cyl(n,p,rad,depth,ma,parent=None,rot=(0,0,0),r2=None):
 bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=rad,radius2=rad if r2 is None else r2,depth=depth,location=p,rotation=rot)
 o=own(bpy.context.object,n,parent);o.data.materials.append(M[ma]);
 mod=o.modifiers.new('Soft rim','BEVEL');mod.width=.035;mod.segments=2
 mod=o.modifiers.new('Normals','WEIGHTED_NORMAL');return o

def export(name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in collection.objects:o.select_set(True)
 bpy.context.view_layer.objects.active=next(iter(collection.objects))
 bpy.ops.export_scene.gltf(filepath=OUT+'/'+name+'.glb',use_selection=True,export_format='GLB',export_yup=True,export_animations=False)

begin('Mogu the kaiju')
rig=joint('Rig');hips=joint('Hips',(0,0,.95),rig)
ell('Body',(0,.05,.26),(.69,.51,.83),'coral',hips)
ell('Belly',(0,-.415,.20),(.48,.12,.57),'cream',hips)
for z in [-.04,.14,.32]:box('Belly fold',(0,-.523,z),(.62,.025,.024),'ivory',hips,.012)
head=joint('Head',(0,-.08,.99),hips)
ell('Crown',(0,0,.12),(.72,.57,.58),'coral',head)
ell('Muzzle',(0,-.42,-.01),(.66,.36,.31),'coral',head)
ell('Mouth cavity',(0,-.78,-.18),(.43,.04,.11),'mouth',head)
for x in [-.40,.40]:
 ell('Eye white',(x,-.43,.32),(.22,.16,.245),'ivory',head)
 ell('Pupil',(x,-.569,.32),(.107,.064,.143),'ink',head)
 ell('Eye shine',(x-.028,-.626,.371),(.036,.022,.042),'white',head)
 ell('Cheek',(x*1.40,-.45,-.01),(.105,.047,.065),'pink',head)
 b=box('Brow',(x,-.46,.556),(.29,.092,.079),'coral',head,.035);b.rotation_euler.y=-.12 if x<0 else .12
for x in [-.20,.20]:ell('Nostril',(x,-.71,.03),(.049,.021,.035),'mouth',head)
jaw=joint('Jaw',(0,-.28,-.23),head)
ell('Lower jaw',(0,-.16,-.04),(.56,.34,.15),'coral',jaw)
ell('Tongue',(0,-.31,.075),(.28,.14,.046),'pink',jaw)
for x in [-.39,-.22,.22,.39]:cyl('Tooth',(x,-.30 if abs(x)>.3 else -.39,.05),.06,.12,'ivory',jaw,r2=.014)
for side,x in [('L',-.43),('R',.43)]:
 leg=joint('Leg'+side,(x,0,-.45),hips)
 ell('Thigh'+side,(0,.01,-.09),(.30,.31,.34),'coral',leg)
 ell('Foot'+side,(0,-.14,-.35),(.30,.43,.18),'coral',leg)
 for dx in [-.16,0,.16]:ell('Toe',(dx,-.49,-.35),(.075,.11,.074),'ivory',leg)
 arm=joint('Arm'+side,(x*1.5,-.04,.49),hips)
 ell('UpperArm'+side,(x*.13,-.07,-.15),(.17,.20,.30),'coral',arm)
 ell('Palm'+side,(x*.14,-.18,-.34),(.19,.19,.19),'coral',arm)
 for dx in [-.09,.07]:ell('Claw',(dx,-.32,-.39),(.05,.085,.067),'ivory',arm)
tail=joint('Tail',(0,.43,-.13),hips)
a=ell('Tail base',(0,.37,-.12),(.35,.65,.28),'coral',tail);a.rotation_euler.x=-.12
ell('Tail tip',(0,.93,-.23),(.15,.42,.14),'coral',tail)
for y,z,s in [(.52,.84,.18),(.64,.48,.19),(.82,.14,.17),(1.09,-.03,.12)]:
 cyl('Back fin',(0,y,z),s,s*2.5,'cream',hips,rot=(.35,0,0),r2=.012)
export('mogu')

for name,color in [('car','teal'),('taxi','mustard')]:
 begin(name);box('Chassis',(0,0,.45),(1.4,2.45,.52),color,bevel=.16)
 box('Cabin',(0,-.08,.92),(1.19,1.18,.61),color,bevel=.20)
 box('Front windshield',(0,-.655,.96),(1.04,.032,.37),'glass',bevel=.05)
 box('Rear windshield',(0,.51,.96),(.99,.03,.34),'glass',bevel=.05)
 for x in [-.605,.605]:
  for y in [-.34,.23]:box('Side glass',(x,y,.99),(.025,.48,.31),'glass',bevel=.04)
 for x in [-.70,.70]:
  for y in [-.72,.72]:cyl('Wheel',(x,y,.32),.31,.16,'rubber',rot=(0,math.pi/2,0));cyl('Hub',(x*1.06,y,.32),.15,.17,'ivory',rot=(0,math.pi/2,0))
 for x in [-.46,.46]:box('Headlamp',(x,-1.24,.51),(.26,.04,.17),'ivory',bevel=.04);box('Tail light',(x,1.235,.54),(.23,.04,.14),'coral',bevel=.03)
 box('Bumper',(0,-1.27,.29),(1.20,.10,.12),'steel',bevel=.04)
 if name=='taxi':box('Taxi lamp',(0,0,1.3),(.38,.23,.13),'ivory',bevel=.04)
 export(name)

for name,ma in [('tank','blue'),('hunter','coral'),('mortar','mustard')]:
 begin(name)
 for x in [-.77,.77]:
  box('Track',(x,0,.43),(.43,2.65,.74),'rubber',bevel=.18)
  for y in [-.87,-.30,.30,.87]:cyl('Track wheel',(x*1.26,y,.43),.24,.04,'steel',rot=(0,math.pi/2,0))
 box('Armour',(0,0,.80),(1.75,2.24,.70),ma,bevel=.16)
 turret=joint('Turret',(0,-.1,1.3))
 box('Turret shell',(0,0,0),(1.17,1.20,.54),ma,turret,.14)
 box('Hatch',(0,.15,.32),(.50,.51,.10),'ivory',turret,.05)
 cyl('Barrel',(0,-1.0,.08),.13,1.35,'steel',turret,rot=(math.pi/2,0,0))
 cyl('Muzzle',(0,-1.69,.08),.21,.25,ma,turret,rot=(math.pi/2,0,0))
 if name=='mortar':
  for x in [-.35,.35]:cyl('Mortar tube',(x,.06,.62),.23,1.0,'steel',turret,rot=(.3,0,0))
 if name=='hunter':
  for x in [-.43,.43]:box('Ram blade',(x,-1.3,.65),(.37,.36,.56),'ivory',bevel=.03)
 box('Rear core',(0,1.13,.98),(.60,.055,.36),'core',bevel=.08)
 export(name)

begin('vending')
box('Machine',(0,0,.90),(.95,.68,1.80),'coral',bevel=.10)
box('Display',(0,-.36,1.14),(.77,.025,.94),'glass',bevel=.03)
for x in [-.25,0,.25]:
 for z in [.85,1.13,1.4]:cyl('Can',(x,-.40,z),.055,.14,'ivory')
box('Delivery slot',(0,-.36,.37),(.51,.03,.19),'ink',bevel=.03)
box('Label',(0,-.37,1.63),(.74,.03,.11),'ivory',bevel=.02)
export('food')

for name,ma,stories in [('shop','ivory',2),('apartment','blue',4),('bakery','pink',2)]:
 begin(name);h=stories*1.25
 box('Foundation',(0,0,.13),(4.4,4.0,.26),'steel',bevel=.06)
 # Separate storeys are visible fracture units.
 for level in range(stories):
  z=.26+level*1.25
  box('Storey'+str(level),(0,0,z+.61),(4,3.6,1.19),ma,bevel=.04)
  box('Trim'+str(level),(0,0,z+1.2),(4.10,3.70,.13),'ivory',bevel=.015)
  for x in [-1.28,0,1.28]:
   box('Window',(x,-1.82,z+.64),(.87,.03,.76),'glass',bevel=.035)
   box('Sill',(x,-1.91,z+.23),(.99,.20,.10),'white',bevel=.02)
   box('Mullion',(x,-1.853,z+.64),(.034,.02,.76),'ivory',bevel=.005)
  for y in [-.95,.55]:box('SideWindow',(2.017,y,z+.64),(.03,.85,.70),'glass',bevel=.03)
 box('Roof',(0,0,h+.36),(4.25,3.85,.24),'teal',bevel=.05)
 box('Rooftop unit',(.7,.5,h+.73),(1.0,.85,.5),'steel',bevel=.08)
 for x in [-1.5,-.9,-.3,.3,.9,1.5]:
  aw=box('Awning',(x,-2.04,1.64),(.58,.73,.13),'coral' if x in [-1.5,-.3,.9] else 'ivory',bevel=.02);aw.rotation_euler.x=.18
 box('Shop sign',(0,-1.855,2.2),(3.25,.12,.51),'teal',bevel=.045)
 for x in [-.95,0,.95]:ell('Sign emblem',(x,-1.938,2.2),(.20,.035,.15),'cream')
 export(name)

begin('boss')
rig=joint('Rig');body=joint('Body',(0,0,3.1),rig)
box('Engine',(0,0,.3),(3.5,2.6,2.2),'mustard',body,.25)
box('Cabin',(0,-.45,1.54),(2.7,1.9,1.5),'mustard',body,.25)
box('Face visor',(0,-1.44,1.59),(2.23,.08,.70),'glass',body,.10)
for x in [-.62,.62]:box('Eye',(x,-1.51,1.62),(.40,.03,.15),'ivory',body,.03)
for side,x in [('L',-1.6),('R',1.6)]:
 leg=joint('Leg'+side,(x,.3,-.8),body)
 box('Upper leg',(0,0,-.34),(.85,.9,1.1),'steel',leg,.1)
 box('Shin',(0,-.13,-1.23),(1.10,1.10,1.15),'mustard',leg,.1)
 box('Foot',(0,-.50,-1.95),(1.6,2.0,.55),'steel',leg,.1)
 arm=joint('Arm'+side,(x*1.34,0,.54),body)
 cyl('Shoulder',(0,0,0),.57,.55,'steel',arm,rot=(0,math.pi/2,0))
 box('Arm',(0,-.1,-.65),(.8,.8,1.4),'mustard',arm,.12)
 cyl('Roller',(0,-.4,-1.5),.85,1.5,'steel',arm,rot=(0,math.pi/2,0))
ell('Core',(0,-1.34,-.03),(.61,.20,.61),'core',body)
for x in [-1.2,1.2]:cyl('Exhaust',(x,.7,2),.17,1.8,'steel',body)
export('boss')

begin('tree');cyl('Trunk',(0,0,.7),.16,1.4,'cream');ell('Canopy',(0,0,1.7),(.83,.78,.94),'teal');ell('Crown',(.1,0,2.25),(.61,.58,.6),'teal');export('tree')
begin('core');ell('Energy',(0,0,.50),(.39,.39,.45),'core');cyl('Band',(0,0,.45),.44,.16,'ivory');export('core')
# Store sources in separately named collections; all props rest at origin for individual export.
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/source/miniatures.blend')
