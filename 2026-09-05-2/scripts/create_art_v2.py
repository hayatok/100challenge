"""Author the second art source. Curved tailored character, articulated parts, dense street set.
The original kit and any reviewed v2 source are never overwritten by this constructor.
"""
import bpy, math, os, random
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET=os.path.join(ROOT,'art/source/amedori-v2.blend')
if os.path.exists(TARGET): raise RuntimeError('V2 source already exists; edit the saved source instead.')
bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(905)
M={}
def material(name,h,rough=.6,metal=0,emission=0):
 c=[int(h[i:i+2],16)/255 for i in (0,2,4)];c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 if emission:bs.inputs['Emission Color'].default_value=(*c,1);bs.inputs['Emission Strength'].default_value=emission
 M[name]=m;return m
for args in [('ink','17242C',.42),('hair','302636',.27),('hairlight','554055',.3),('hairshine','765565',.34),('pink','CF536B',.54),('pinklight','EC8190',.62),('pinkdark','8E364D',.72),('lining','6E3650',.8),('skin','F0BEA5',.6),('blush','D9958C',.65),('cream','F1E1BD',.7),('white','FFF2DA',.6),('iris','B76135',.3),('pupil','19192A',.28),('cyan','53DAD7',.32,.15,1.2),('gold','E4BD75',.3,.7),('metal','6C838D',.26,.85),('rubber','17232C',.8),('orange','E99B57',.46,.25),('slate','344852',.65),('wood','76574B',.8),('woodlight','B58A6A',.8),('wall','52616A',.95),('brick','8B6F62',.95),('plaster','B0AEA0',.95),('tile','456D6C',.36),('tilelight','70938A',.38),('glass','243D45',.16,.65),('light','F4B968',.4,0,2.2),('neon','F38297',.3,0,2.5),('leaf','477564',.8),('leaflight','81A78B',.8),('road','34424A',.55),('water','4D646D',.1,.7),('paint','C0B5A0',.88)]:material(*args)
def empty(name,parent=None,at=(0,0,0)):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=at;return o
def finish(o,name,parent,at,mat):
 o.name=name;o.parent=parent;o.location=at;o.data.materials.append(M[mat]);return o
def smooth(o):
 for f in o.data.polygons:f.use_smooth=True
 return o
def box(name,p,at,size,mat,bevel=.03,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add();o=bpy.context.object;o.scale=Vector(size)*.5;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 finish(o,name,p,at,mat);o.rotation_euler=rot
 if bevel:
  b=o.modifiers.new('machined_edge','BEVEL');b.width=bevel;b.segments=3
  n=o.modifiers.new('weighted_normals','WEIGHTED_NORMAL')
 return o
def ell(name,p,at,size,mat,seg=24):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=16);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return smooth(finish(o,name,p,at,mat))
def cyl(name,p,at,r,depth,mat,rot=(0,0,0),vertices=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth);o=finish(bpy.context.object,name,p,at,mat);o.rotation_euler=rot
 b=o.modifiers.new('rim_bevel','BEVEL');b.width=min(.015,r*.15);b.segments=2;return smooth(o)
def line(name,p,points,r,mat,res=3):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=12;c.bevel_depth=r;c.bevel_resolution=res
 s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
 for b,v in zip(s.bezier_points,points):b.co=v;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=p;c.materials.append(M[mat]);return o
def ring(name,p,at,major,minor,mat,rot=(0,0,0),n=32):
 bpy.ops.mesh.primitive_torus_add(major_segments=n,minor_segments=8,location=(0,0,0),major_radius=major,minor_radius=minor)
 o=finish(bpy.context.object,name,p,at,mat);o.rotation_euler=rot;return smooth(o)
def loft(name,p,rings,mat,n=32,sub=1):
 # Each ring: z, x radius, y radius, x offset, y offset. Hand-authored silhouettes.
 vs=[];fs=[]
 for z,rx,ry,x,y in rings:
  for j in range(n):
   a=j*math.tau/n;vs.append((x+rx*math.cos(a),y+ry*math.sin(a),z))
 for k in range(len(rings)-1):
  for j in range(n):a=k*n+j;b=k*n+(j+1)%n;fs.append((a,b,b+n,a+n))
 fs.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+j for j in range(n))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.parent=p;mesh.materials.append(M[mat]);smooth(o)
 if sub:m=o.modifiers.new('tailored_surface','SUBSURF');m.levels=sub;m.render_levels=sub
 return o
def text(name,p,at,body,size,mat,rot=(math.pi/2,0,0)):
 c=bpy.data.curves.new(name,'FONT');c.body=body;c.size=size;c.align_x='CENTER';c.align_y='CENTER';c.extrude=.003;c.bevel_depth=.001;c.resolution_u=3
 c.font=font;o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=p;o.location=at;o.rotation_euler=rot;c.materials.append(M[mat]);return o
font=bpy.data.fonts.load(os.path.join(ROOT,'game/assets/fonts/NotoSansCJKjp-Medium.otf'))
# --- KOHAKU: layered streetwear, individual hair locks and articulated limbs. ---
p=empty('kohaku')
body=empty('body',p)
loft('tailored_jacket',body,[(1.02,.27,.17,0,0),(1.04,.29,.18,0,0),(1.12,.31,.185,0,0),(1.3,.26,.175,0,0),(1.48,.30,.19,0,0),(1.62,.34,.175,0,.015),(1.68,.23,.125,0,.02)],'pink',40,2)
loft('ribbed_hem',body,[(1.02,.283,.184,0,0),(1.055,.285,.184,0,0),(1.09,.29,.184,0,0)],'pinkdark',40,1)
# shirt insert follows body rather than a flat cube.
loft('ivory_shirt',body,[(1.09,.15,.184,0,-.004),(1.3,.145,.181,0,-.006),(1.55,.14,.195,0,-.008),(1.65,.10,.16,0,-.01)],'cream',32,1)
for s in [-1,1]:
 line('zipper_tape',body,[(s*.10,-.17,1.64),(s*.16,-.197,1.48),(s*.16,-.194,1.20),(s*.15,-.188,1.06)],.012,'pinkdark')
 line('zipper_metal',body,[(s*.105,-.19,1.59),(s*.155,-.211,1.44),(s*.158,-.204,1.13)],.005,'metal',2)
 line('collar',body,[(s*.10,-.10,1.7),(s*.22,-.15,1.64),(s*.15,-.22,1.48)],.045,'pinklight')
 line('pocket_piping',body,[(s*.19,-.19,1.23),(s*.25,-.16,1.30)],.007,'cream',2)
 line('side_seam',body,[(s*.29,-.06,1.12),(s*.265,-.065,1.38),(s*.30,-.065,1.57)],.004,'pinklight',2)
 box('pocket_flap',body,(s*.215,-.181,1.26),(.075,.016,.052),'pinkdark',.014,rot=(0,s*-.45,0))
 for z in [1.14,1.19,1.24]:ell('metal_snap',body,(s*.16,-.213,z),(.01,.007,.01),'gold',16)
# hood with inner lining and drawstrings
ring('hood_fold',body,(0,.085,1.63),.195,.066,'pinklight',rot=(.25,0,0))
for s in [-1,1]:
 line('hood_string',body,[(s*.16,-.12,1.65),(s*.20,-.225,1.43),(s*.18,-.23,1.35)],.009,'cream')
 cyl('cord_tip',body,(s*.18,-.231,1.34),.012,.046,'gold')
# pleated skirt, wavy radius produces sewn panels rather than a cone primitive.
vs=[];fs=[];n=96
for k,(z,r) in enumerate([(1.08,.24),(1.045,.255),(.85,.35),(.81,.36)]):
 for j in range(n):
  a=j*math.tau/n;v=r+(0 if k<2 else .016*math.cos(a*16));vs.append((v*math.cos(a),v*.69*math.sin(a),z+.009*math.cos(a*16)))
for k in range(3):
 for j in range(n):a=k*n+j;b=k*n+(j+1)%n;fs.append((a,b,b+n,a+n))
me=bpy.data.meshes.new('pleats');me.from_pydata(vs,[],fs);o=bpy.data.objects.new('pleated_skirt',me);bpy.context.collection.objects.link(o);o.parent=body;me.materials.append(M['ink']);smooth(o)
for s in [-1,1]:
 leg=empty('leg_L' if s<0 else 'leg_R',p,(s*.145,0,.9))
 loft('stocking',leg,[(-.73,.066,.064,0,0),(-.62,.067,.069,0,.018),(-.43,.077,.08,0,.015),(-.34,.065,.073,0,-.015),(-.14,.092,.092,0,0),(0,.09,.09,0,0)],'ink',32,2)
 ring('stocking_cuff',leg,(0,0,-.10),.09,.01,'pinklight')
 # sculpted sneaker with separate sole, heel guard, toe and laces
 ell('shoe_upper',leg,(0,-.07,-.77),(.095,.175,.078),'cream')
 box('layered_sole',leg,(0,-.063,-.835),(.207,.34,.052),'rubber',.037)
 box('sole_inset',leg,(0,-.067,-.809),(.209,.338,.027),'white',.025)
 box('cyan_heel',leg,(0,.073,-.765),(.16,.055,.06),'cyan',.016)
 line('sneaker_side_panel',leg,[(s*.091,-.15,-.774),(s*.10,-.06,-.74),(s*.079,.055,-.73)],.015,'pink')
 for j in range(4):
  y=-.12+j*.035
  line('crossed_laces',leg,[(-.05,y,-.707),(0,y+.024,-.70),(.05,y,-.707)],.006,'white',2)
 arm=empty('arm_L' if s<0 else 'arm_R',p,(s*.31,0,1.58))
 loft('oversized_sleeve',arm,[(-.56,.087,.084,s*.073,0),(-.52,.099,.09,s*.085,0),(-.39,.135,.119,s*.074,.018),(-.25,.14,.125,s*.052,.018),(-.08,.14,.13,s*.032,0),(.02,.11,.10,0,0)],'pink',32,2)
 loft('ribbed_cuff',arm,[(-.575,.086,.085,s*.073,0),(-.54,.09,.087,s*.077,0),(-.515,.095,.09,s*.08,0)],'pinkdark',32,1)
 for z in [-.18,-.25,-.36]:
  line('sleeve_fold',arm,[(s*.16,-.08,z+.025),(s*.1,-.127,z),(s*.005,-.095,z-.025)],.005,'pinklight',2)
 ell('palm',arm,(s*.074,-.008,-.625),(.055,.045,.069),'skin')
 for j in range(4):ell('finger',arm,(s*.04+j*s*.018,-.024,-.67),(.012,.019,.044),'skin',16)
 ell('thumb',arm,(s*.024,-.048,-.625),(.021,.024,.038),'skin',16)
 if s==1:
  cyl('wireless_mic_body',arm,(s*.076,-.075,-.59),.026,.22,'metal')
  ring('mic_ring',arm,(s*.076,-.075,-.48),.036,.009,'cyan')
  ell('microphone_mesh',arm,(s*.076,-.075,-.44),(.05,.05,.064),'ink')
  for z in [-.47,-.44,-.41]:ring('mic_grille',arm,(s*.076,-.075,z),.041,.003,'metal',n=24)
# collar and face with jaw/chin profile
cyl('neck',body,(0,0,1.76),.09,.22,'skin')
head=empty('head',body,(0,0,1.96))
loft('face_sculpt',head,[(-.20,.035,.058,0,-.055),(-.175,.095,.09,0,-.035),(-.12,.15,.134,0,-.006),(-.025,.186,.157,0,0),(.075,.19,.161,0,.005),(.17,.158,.135,0,.02),(.23,.08,.077,0,.025)],'skin',48,2)
# Anime inset eyes: ivory sclera, warm iris, pupil, specular points, sculpted lids.
for s in [-1,1]:
 eye=ell('eye_white',head,(s*.082,-.148,.015),(.058,.018,.042),'white',32);eye.rotation_euler.y=s*.07
 ell('amber_iris',head,(s*.082,-.165,.012),(.027,.009,.034),'iris',32)
 ell('pupil',head,(s*.082,-.174,.016),(.012,.004,.026),'pupil',24)
 ell('eye_glint',head,(s*.075,-.18,.032),(.009,.003,.011),'white',16)
 line('upper_lash',head,[(s*.026,-.152,.04),(s*.073,-.169,.058),(s*.121,-.148,.049),(s*.145,-.126,.061)],.007,'hair',3)
 line('lower_lid',head,[(s*.034,-.155,-.011),(s*.082,-.169,-.025),(s*.13,-.14,-.008)],.0025,'blush',2)
 line('eyebrow',head,[(s*.032,-.141,.10),(s*.085,-.151,.113),(s*.136,-.124,.10)],.007,'hair',3)
 ell('cheek_tint',head,(s*.129,-.121,-.063),(.035,.006,.012),'blush',24)
 ell('ear',head,(s*.184,.005,-.019),(.025,.031,.05),'skin')
 ring('ear_stud',head,(s*.205,-.01,-.038),.011,.004,'gold',rot=(math.pi/2,0,0))
ell('nose',head,(0,-.166,-.06),(.019,.022,.031),'skin')
line('mouth',head,[(-.03,-.135,-.121),(0,-.148,-.129),(.032,-.134,-.12)],.0035,'pinkdark')
# Open hair cap: upper ellipsoid patch, not a sphere hiding the face.
vs=[];fs=[];ns=64;nr=14
for i in range(nr+1):
 for j in range(ns):
  phi=j*math.tau/ns;front=max(0,-math.sin(phi));limit=2.1-.82*front;t=(i+.06)/(nr+.06)*limit
  vs.append((.207*math.sin(t)*math.cos(phi),.017+.188*math.sin(t)*math.sin(phi),.045+.235*math.cos(t)))
for i in range(nr):
 for j in range(ns):a=i*ns+j;b=i*ns+(j+1)%ns;fs.append((a,b,b+ns,a+ns))
me=bpy.data.meshes.new('hair_crown');me.from_pydata(vs,[],fs);o=bpy.data.objects.new('hair_crown',me);bpy.context.collection.objects.link(o);o.parent=head;me.materials.append(M['hair']);smooth(o)
def lock(name,parent,points,widths,mat='hair'):
 # Elliptical sweep with pointed tip; z-oriented locks authored individually.
 rings=[]
 for v,w in zip(points,widths):rings.append((v[2],w,w*.4,v[0],v[1]))
 return loft(name,parent,rings,mat,16,2)
for s in [-1,1]:
 for j in range(4):
  x=s*(.025+j*.044)
  lock('swept_fringe',head,[(x,.002,.265),(x+s*.025,-.12,.208),(x+s*.025,-.17,.126),(x-s*.02,-.179,.058+j*.019)],[.018,.039,.043,.002], 'hair' if j%2 else 'hairlight')
 for j in range(3):
  lock('side_lock',head,[(s*.17,.02,.20),(s*(.20+j*.018),-.016,.045),(s*(.19+j*.018),-.035,-.16),(s*(.18+j*.018),-.04,-.25-j*.02)],[.035,.045,.037,.002])
 pony=empty('pony_L' if s<0 else 'pony_R',head,(s*.19,.095,.10))
 ring('hair_tie',pony,(s*.015,0,0),.051,.016,'pinklight',rot=(0,math.pi/2,0))
 for j in range(5):
  lock('ribbon_hair',pony,[(s*.025,j*.016-.02,.03),(s*(.1+j*.008),.02,-.08),(s*(.13+j*.009),.018,-.24),(s*(.10+j*.015),-.015,-.40-j*.016)],[.025,.043,.047,.002], 'hairlight' if j==1 else 'hair')
 for j in [0,1]:
  line('hair_specular',head,[(s*.06+j*s*.065,-.09,.234),(s*.075+j*s*.06,-.15,.183),(s*.09+j*s*.058,-.176,.132)],.003,'hairshine',2)
# headphones frame on crown and machined earcups
line('headphone_band',head,[(-.21,.025,.03),(-.21,.038,.23),(0,.03,.30),(.21,.038,.23),(.21,.025,.03)],.024,'ink')
line('headphone_trim',head,[(-.21,.004,.12),(-.18,.004,.245),(0,.007,.29),(.18,.004,.245),(.21,.004,.12)],.007,'gold')
for s in [-1,1]:
 cyl('headphone_cup',head,(s*.225,.025,.023),.072,.044,'metal',rot=(0,math.pi/2,0))
 cyl('headphone_glow',head,(s*.251,.025,.023),.052,.009,'cyan',rot=(0,math.pi/2,0))
 cyl('headphone_core',head,(s*.259,.025,.023),.035,.01,'ink',rot=(0,math.pi/2,0))
# backpack with seams, buckles and radio
box('backpack',body,(0,.23,1.37),(.31,.18,.39),'ink',.07)
box('pack_flap',body,(0,.332,1.49),(.275,.034,.11),'pinkdark',.025)
for s in [-1,1]:
 line('shoulder_strap',body,[(s*.10,.31,1.2),(s*.23,.16,1.63),(s*.21,-.15,1.53),(s*.26,-.14,1.23)],.025,'ink')
 box('strap_buckle',body,(s*.22,-.177,1.48),(.05,.024,.068),'gold',.01)
# --- CALL BIT: assembled field speaker drone. ---
e=empty('call_bit',at=(3,0,0))
box('cast_shell',e,(0,0,.5),(.53,.36,.56),'orange',.095)
box('rubber_bumper',e,(0,.005,.5),(.56,.28,.42),'ink',.065)
box('front_bezel',e,(0,-.197,.50),(.44,.058,.46),'metal',.065)
box('front_inset',e,(0,-.23,.49),(.382,.034,.399),'ink',.045)
ring('speaker_surround',e,(0,-.255,.46),.126,.017,'rubber',rot=(math.pi/2,0,0))
cyl('speaker_cone',e,(0,-.249,.46),.112,.026,'slate',rot=(math.pi/2,0,0),vertices=32)
ell('speaker_dustcap',e,(0,-.271,.46),(.054,.018,.054),'gold')
for x in [-.165,.165]:
 for z in [.34,.66]:cyl('face_bolt',e,(x,-.26,z),.014,.012,'gold',rot=(math.pi/2,0,0),vertices=12)
box('display',e,(0,-.26,.65),(.24,.018,.057),'rubber',.01)
for x in [-.065,.065]:box('signal_eye',e,(x,-.273,.651),(.055,.007,.016),'cyan',.006)
for s in [-1,1]:
 cyl('hip_axle',e,(s*.21,.01,.24),.056,.1,'metal',rot=(0,math.pi/2,0))
 line('articulated_leg',e,[(s*.21,0,.26),(s*.255,.035,.16),(s*.215,-.035,.08)],.029,'ink')
 box('stabilizer_foot',e,(s*.235,-.055,.055),(.125,.20,.065),'rubber',.028)
 for z in [.36,.43,.50]:box('side_vent',e,(s*.271,0,z),(.008,.19,.016),'metal',.003)
box('carry_handle',e,(0,.025,.83),(.25,.13,.036),'ink',.02)
for x in [-.11,.11]:box('handle_mount',e,(x,.025,.79),(.03,.11,.08),'metal',.01)
line('aerial',e,[(.18,.07,.76),(.22,.07,.9),(.22,.07,1.01)],.012,'metal')
ell('signal_tip',e,(.22,.07,1.02),(.026,.026,.026),'cyan',16)
# --- STREET: authored full block, varied silhouettes and storefront stories. ---
st=empty('street',at=(0,0,0))
box('subgrade',st,(0,0,-.23),(54,39,.4),'slate',.06)
# Gameplay occupies x±20, y±12; streetscape stays beyond that clear area.
for x in [-22,22]:
 box('sidewalk',st,(x,0,-.025),(2.5,29,.28),'plaster',.06)
 for y in range(-14,15):box('curb_stone',st,(x+(.99 if x<0 else -.99),y,.055),(.25,.96,.22),'slate',.035)
for y in [-14,14]:
 box('walkway',st,(0,y,-.025),(45,2.4,.28),'plaster',.06)
 for x in range(-22,23):box('curb_stone',st,(x,y+(.99 if y<0 else -.99),.055),(.96,.25,.22),'slate',.035)
# Floor small objects and wear, no checkerboard.
for x in [-19.7,19.7]:
 for y in range(-11,12,2):
  box('drain_bed',st,(x,y,.011),(.34,1.65,.027),'ink',.006)
  for j in range(8):box('drain_grating',st,(x,y-.7+j*.2,.033),(.30,.025,.02),'metal',.004)
for x,y in [(-9,-5),(10,5),(3,-10)]:
 cyl('manhole_plate',st,(x,y,.019),.58,.033,'metal',vertices=48)
 ring('manhole_rim',st,(x,y,.037),.56,.014,'ink')
 for j in range(-4,5):
  w=math.sqrt(max(0,.45**2-(j*.095)**2))*2
  if w>0:box('manhole_ribs',st,(x,y+j*.095,.041),(w,.028,.02),'ink',.004)
for x in [-11.5,11.5]:
 for y in range(-10,12,3):
  box('worn_lane_paint',st,(x,y,.008),(.09,1.6,.008),'paint',0)
for x,y in [(-17,8),(16,-6),(5,9),(-4,-9)]:
 # irregular flat wet patches are real curved meshes with low roughness.
 n=40;vs=[(x,y,.013)]
 for j in range(n):
  a=j*math.tau/n;r=1+.2*math.sin(a*3)+.1*math.sin(a*7);vs.append((x+math.cos(a)*r*1.8,y+math.sin(a)*r*.55,.013))
 me=bpy.data.meshes.new('puddle');me.from_pydata(vs,[],[(0,j+1,(j+1)%n+1) for j in range(n)]);o=bpy.data.objects.new('rain_puddle',me);bpy.context.collection.objects.link(o);o.parent=st;me.materials.append(M['water'])
# Top street row faces the player/camera. Godot converts Blender -Y to +Z.
# Place at Blender +Y = Godot -Z.
names=['喫茶 雨音','雨灯レコード','らぁめん 月','よふかし機材','花と灯り','小劇場 SIGNAL','古書 雨宿り']
colors=['tile','brick','plaster','slate','wood','pinkdark','wall']
for idx,x in enumerate([-18,-12,-6,0,6,12,18]):
 shop=empty('shop_%02d'%idx,st,(x,15.7,0));h=[7.2,9.3,6.6,8.2,6.9,10,7.5][idx];wall=colors[idx]
 box('building_mass',shop,(0,1.2,h/2),(5.75,4.0,h),wall,.065)
 box('parapet',shop,(0,1.2,h+.09),(5.95,4.1,.2),'slate',.04)
 box('fascia',shop,(0,-.86,3.2),(5.68,.32,.64),'ink',.04)
 box('sign_face',shop,(0,-1.038,3.22),(5.38,.06,.43),'woodlight' if idx%2 else 'pinkdark',.02)
 text('store_name',shop,(0,-1.08,3.22),names[idx],.41,'light' if idx%2 else 'cream')
 # recessed storefront, mullions, timber door and tiled plinth
 box('shop_recess',shop,(0,-.91,1.5),(5.45,.16,2.3),'ink',.02)
 for xx in [-1.9,-.95,0,.95,1.9]:
  box('window_glass',shop,(xx,-1.024,1.57),(.86,.033,2.04),'glass',.012)
  box('window_stile',shop,(xx-.46,-1.06,1.57),(.045,.07,2.19),'woodlight',.006)
  box('warm_interior',shop,(xx,-.96,1.5),(.60,.04,1.6),'light',.012)
  for z in [.63,1.38,2.16]:box('window_crossbar',shop,(xx,-1.08,z),(.90,.07,.04),'woodlight',.005)
 box('door_handle',shop,(.30,-1.13,1.37),(.027,.09,.30),'gold',.01)
 for z in [.13,.31]:
  for j in range(18):box('ceramic_plinth',shop,(-2.65+j*.31,-1.07,z),(.296,.12,.16),'tile' if j%3 else 'tilelight',.008)
 # Canopies, thick fabric edge and supporting brackets.
 awning=empty('awning',shop,(0,-1.23,2.86));awning.rotation_euler.x=.14
 for j in range(12):
  mat='cream' if j%2 else ('pinkdark' if idx%2 else 'tile')
  box('canvas_panel',awning,(-2.64+j*.48,-.47,0),(.49,1.18,.065),mat,.02)
  box('hanging_valance',awning,(-2.64+j*.48,-1.03,-.12),(.49,.055,.25),mat,.014)
 for xx in [-2.3,2.3]:line('canopy_brace',shop,[(xx,-.92,2.25),(xx,-2.13,2.78),(xx,-1.04,2.78)],.032,'metal')
 # Three-dimensional upper windows with curtains and balconies.
 for z in [4.35,6.25,8.2]:
  if z+.7>h:continue
  for xx in [-1.7,0,1.7]:
   box('window_surround',shop,(xx,-.835,z),(1.3,.14,1.38),'slate',.02)
   box('upper_glass',shop,(xx,-.924,z),(1.12,.025,1.19),'glass' if (idx+int(z)+int(xx))%3 else 'light',.01)
   for dx in [-.32,.32]:box('curtain',shop,(xx+dx,-.947,z),(.29,.015,1.14),'woodlight',.006)
   box('window_divider',shop,(xx,-.964,z),(.035,.07,1.24),'metal',.004)
   box('sill',shop,(xx,-.99,z-.68),(1.45,.32,.09),'plaster',.015)
   if z<5:
    box('balcony_base',shop,(xx,-1.23,z-.77),(1.52,.66,.12),'slate',.02)
    for j in range(7):cyl('balcony_rail',shop,(xx-.66+j*.22,-1.51,z-.33),.015,.8,'metal',vertices=12)
    line('balcony_toprail',shop,[(xx-.75,-.95,z+.06),(xx-.75,-1.52,z+.06),(xx+.75,-1.52,z+.06),(xx+.75,-.95,z+.06)],.025,'metal')
 # Utility hardware: ducting, conduit, AC vents and roof water tanks.
 line('rain_downpipe',shop,[(2.63,-.86,h-.2),(2.63,-.94,3.8),(2.69,-1.06,.3)],.053,'metal')
 acx=2.06
 box('air_conditioner',shop,(acx,-1.16,4.2),(1.06,.54,.6),'plaster',.04)
 cyl('fan_grille',shop,(acx-.19,-1.445,4.2),.23,.035,'ink',rot=(math.pi/2,0,0))
 for j in range(5):
  a=j*math.tau/5;line('fan_spoke',shop,[(acx-.19,-1.47,4.2),(acx-.19+.2*math.sin(a),-1.47,4.2+.2*math.cos(a))],.01,'metal',1)
 for j in range(6):box('AC_louver',shop,(acx+.30,-1.449,4.0+j*.07),(.21,.03,.02),'metal',.003)
 cyl('rooftop_tank',shop,(1.5,1.3,h+.65),.5,1.15,'metal',vertices=32)
 for z in [h+.2,h+1.1]:ring('tank_band',shop,(1.5,1.3,z),.502,.025,'ink')
 # Warm cylindrical lanterns outside selected shops.
 for xx in [-2.35,2.35]:
  cyl('lantern',shop,(xx,-1.52,2.28),.19,.46,'light',vertices=32)
  for z in [2.08,2.15,2.22,2.29,2.36,2.43]:ring('lantern_rib',shop,(xx,-1.52,z),.194,.007,'pinkdark')
  cyl('lantern_cap',shop,(xx,-1.52,2.53),.14,.055,'ink')
  line('lantern_hanger',shop,[(xx,-.9,2.65),(xx,-1.52,2.65),(xx,-1.52,2.5)],.015,'metal')
 # Side-mounted sign gives depth to silhouettes.
 box('projecting_sign',shop,(-2.74,-1.13,4.9),(.62,.4,1.8),'ink',.065)
 text('vertical_sign',shop,(-2.74,-1.35,4.9),['COFFEE','VINYL','NOODLE','REPAIR','FLOWER','LIVE','BOOKS'][idx],.16,'cyan',rot=(math.pi/2,0,math.pi/2))
 # Street-level menu boards and planters outside the battle boundary.
 sign=empty('menu_board',shop,(-1.7,-2.3,0));box('menu_frame',sign,(0,0,.64),(.65,.14,1.0),'woodlight',.02,rot=(.1,0,0));box('chalk_face',sign,(0,-.085,.65),(.55,.018,.87),'ink',.01,rot=(.1,0,0))
 text('menu_text',sign,(0,-.16,.72),'OPEN\n本日営業\nCOFFEE / LIVE',.105,'cream')
 for sx in [-.25,.25]:box('board_leg',sign,(sx,.08,.15),(.04,.3,.3),'wood',.01)
 for xx in [.9,2.2]:
  cyl('plant_pot',shop,(xx,-1.8,.25),.25,.47,'woodlight',vertices=24)
  for j in range(9):
   a=j*2.4;leaf=ell('plant_leaf',shop,(xx+math.sin(a)*.18,-1.8+math.cos(a)*.16,.6+j*.023),(.055,.19,.025),'leaf' if j%2 else 'leaflight',16);leaf.rotation_euler=(.4,math.sin(a)*.8,a)
# Side architectural wings; keep the camera foreground low and open.
for s in [-1,1]:
 for y in [-8,0,8]:
  wing=empty('side_annex',st,(s*25,y,0));wing.rotation_euler.z=s*math.pi/2
  box('annex_wall',wing,(0,0,2.2),(7,3.4,4.4),'brick' if y==0 else 'wall',.06)
  box('annex_coping',wing,(0,0,4.45),(7.2,3.6,.18),'ink',.025)
  for xx in [-2.4,0,2.4]:
   box('annex_window',wing,(xx,-1.73,2.4),(1.8,.045,2.15),'glass',.025)
   for z in [1.5,2.4,3.3]:box('annex_mullion',wing,(xx,-1.77,z),(1.86,.07,.045),'metal',.005)
# Corner vending machines, service crates and a small outdoor performance platform.
for x,y in [(-21,9),(21,-7)]:
 v=empty('vending_machine',st,(x,y,0));v.rotation_euler.z=-.18 if x<0 else .18
 box('enamel_body',v,(0,0,.98),(.98,.72,1.96),'pinkdark' if x<0 else 'tile',.075)
 box('illuminated_display',v,(-.13,-.379,1.19),(.58,.04,1.08),'light',.027)
 box('glass_front',v,(-.13,-.411,1.22),(.53,.02,.98),'glass',.014)
 for row in range(3):
  for col in range(4):
   cyl('drink_can',v,(-.33+col*.13,-.44,.87+row*.30),.042,.17,['orange','cyan','cream','pink'][col],vertices=16)
 for z in [.96,1.23,1.50]:box('selection_button',v,(.32,-.42,z),(.1,.035,.055),'cyan',.012)
 box('delivery_slot',v,(-.1,-.41,.3),(.56,.07,.19),'ink',.022)
 text('machine_brand',v,(0,-.389,1.82),'AMEDORI',.11,'cream')
for x in [-18,-12,12,18]:
 for j in range(2):
  box('shipping_crate',st,(x+j*.6,-14.1,.3),(.55,.52,.56),'wood',.025)
  for z in [.1,.28,.46]:box('crate_slat',st,(x+j*.6,-14.38,z),(.56,.025,.04),'woodlight',.004)
# Low stage in foreground: playable alley remains unblocked.
box('street_stage',st,(0,-14.7,.15),(8.5,2.3,.3),'ink',.045)
for j in range(25):box('stage_deck_plank',st,(-4.1+j*.34,-14.7,.316),(.33,2.25,.035),'wood',.008)
for x in [-3.5,3.5]:
 box('PA_cabinet',st,(x,-14.8,1.08),(.85,.63,1.52),'ink',.065)
 for z in [.72,1.38]:
  ring('woofer_rubber',st,(x,-15.14,z),.26,.028,'rubber',rot=(math.pi/2,0,0))
  cyl('woofer',st,(x,-15.12,z),.23,.04,'slate',rot=(math.pi/2,0,0))
  ell('woofer_cap',st,(x,-15.15,z),(.085,.04,.085),'metal')
 for j in range(9):box('PA_grille_bar',st,(x-.32+j*.08,-15.2,1.06),(.013,.013,1.24),'metal',.002)
# Utility poles and gently sagging overhead cables frame the block.
for x in [-21,21]:
 cyl('utility_pole',st,(x,11.9,4.5),.13,9,'wood',vertices=24)
 box('cross_arm',st,(x,11.9,8.2),(1.6,.12,.13),'metal',.025)
 for dx in [-.6,0,.6]:cyl('insulator',st,(x+dx,11.9,8.38),.06,.25,'cream',vertices=16)
for off in [-.6,0,.6]:line('overhead_power',st,[(-21+off,11.9,8.45),(-11,12,7.3),(0,12,7.0),(11,12,7.3),(21+off,11.9,8.45)],.016,'ink',2)
# Streetlamp frames with modeled LED panels. Actual lights are added in Godot.
for x,y in [(-20,-8),(20,7),(-20,7),(20,-8)]:
 cyl('lamp_post',st,(x,y,2.8),.072,5.6,'ink',vertices=20)
 line('lamp_arm',st,[(x,y,5.5),(x,y,5.85),(x+(.8 if x<0 else -.8),y,5.85)],.055,'metal')
 dx=.65 if x<0 else -.65
 box('streetlamp_head',st,(x+dx,y,5.83),(.8,.35,.10),'ink',.04)
 box('LED_panel',st,(x+dx,y,5.775),(.64,.26,.012),'light',.012)
# Save studio camera and lighting in the source, never part of exports.
world=bpy.data.worlds.new('Night studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.08,.12,.18,1);world.node_tree.nodes['Background'].inputs[1].default_value=.5;bpy.context.scene.world=world
for loc,energy,color,size in [((1,-4,7),950,(1,.78,.66),5),((-4,1,5),1100,(.38,.70,1),4),((3,3,6),1300,(1,.35,.28),3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=energy;light.data.color=color;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,1.1))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3.2,-5.2,2.9));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.15))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.8;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
# Hide environment for character studio renders; viewport and exported scene remain visible.
st.hide_render=True;e.hide_render=True
bpy.ops.object.select_all(action='DESELECT')
for obj in p.children_recursive:
 if obj.type=='MESH':obj.select_set(True)
bpy.context.view_layer.objects.active=p
os.makedirs(os.path.dirname(TARGET),exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=TARGET)
print('ART_V2_SAVED',TARGET,len(bpy.data.objects))
