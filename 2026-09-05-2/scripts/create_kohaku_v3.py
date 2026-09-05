"""Character-specific mesh authoring. New source only; never regenerate over reviewed art.
Face uses front-projected painted albedo on a continuous sculpted head. Hair uses tapered
ribbon surfaces. Garments are open thin shells. Existing gameplay pivots are preserved.
"""
import bpy, math, os, random
from mathutils import Vector
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(R,'art/source/kohaku-v3.blend')
if os.path.exists(OUT): raise RuntimeError('Saved V3 exists. Edit that source instead of overwriting it.')
bpy.ops.wm.read_factory_settings(use_empty=True)
M={}
def lin(v):return v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4
def mat(name,h,em=.35,metal=0):
 c=tuple(lin(int(h[i:i+2],16)/255) for i in [0,2,4]);m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*c,1);bs.inputs['Roughness'].default_value=.85;bs.inputs['Metallic'].default_value=metal;bs.inputs['Specular IOR Level'].default_value=.15
 bs.inputs['Emission Color'].default_value=(*c,1);bs.inputs['Emission Strength'].default_value=em;M[name]=m;return m
for name,h in [('skin','F7D3BF'),('hair','28232D'),('hair_mid','37303D'),('hair_light','51404D'),('hair_glint','725563'),('ink','242330'),('charcoal','353340'),('cloth','CF7779'),('cloth_lit','E19493'),('cloth_shadow','A25364'),('lining','583548'),('seam','9A596A'),('ivory','D8D0C3'),('sole','939FAD'),('pink','E6969C'),('metal','8A8D98'),('gold','D6B890'),('teal','66C5CA')]:mat(name,h,em=.5 if name=='skin' else .32,metal=.15 if name in ['metal','gold'] else 0)
face=M['skin'].copy();face.name='face_painted';M['face']=face
im=bpy.data.images.load(os.path.join(R,'game/assets/textures/kohaku-face-v3.png'));im.pack();tex=face.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im;bs=face.node_tree.nodes.get('Principled BSDF');face.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color']);face.node_tree.links.new(tex.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=.65

def empty(name,p=None,at=(0,0,0)):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=p;o.location=at;return o
def mesh(name,p,vs,fs,material,sub=0,solid=0,uv=None):
 m=bpy.data.meshes.new(name);m.from_pydata(vs,[],fs);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);o.parent=p;m.materials.append(M[material])
 for f in m.polygons:f.use_smooth=True
 if uv:
  layer=m.uv_layers.new(name='UVMap')
  for l in m.loops:layer.data[l.index].uv=uv[l.vertex_index]
 if sub:
  a=o.modifiers.new('surface_refinement','SUBSURF');a.levels=sub;a.render_levels=sub
 if solid:
  a=o.modifiers.new('fabric_thickness','SOLIDIFY');a.thickness=solid
 return o
def ell(name,p,at,scale,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20);o=bpy.context.object;o.name=name;o.parent=p;o.location=at;o.scale=scale;o.data.materials.append(M[m])
 for f in o.data.polygons:f.use_smooth=True
 return o
def curve(name,p,pts,r,m):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=16;c.bevel_depth=r;c.bevel_resolution=2;s=c.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
 for b,v in zip(s.bezier_points,pts):b.co=v;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=p;c.materials.append(M[m]);return o
def loft(name,p,rings,m,n=48,sub=2,opening=0,solid=0,fold=0):
 vs=[];fs=[]
 for k,(z,rx,ry,x,y) in enumerate(rings):
  for j in range(n+1):
   a=opening+(math.tau-2*opening)*j/n
   f=fold*math.sin(a*7+k*.7)*math.sin(math.pi*k/(len(rings)-1))
   vs.append((x+(rx+f)*math.sin(a),y-(ry+f*.4)*math.cos(a),z+.003*math.cos(a*5)*fold/.01 if fold else z))
 for k in range(len(rings)-1):
  for j in range(n):a=k*(n+1)+j;fs.append((a,a+1,a+n+2,a+n+1))
 if not opening and not solid:fs.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*(n+1)+j for j in range(n))])
 return mesh(name,p,vs,fs,m,sub,solid)
def patch(name,p,pts,m,solid=.001):return mesh(name,p,pts,[tuple(range(len(pts)))],m,solid=solid)
def box(name,p,at,size,m,bevel=.003):
 bpy.ops.mesh.primitive_cube_add();o=bpy.context.object;o.name=name;o.scale=Vector(size)*.5;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=p;o.location=at;o.data.materials.append(M[m]);b=o.modifiers.new('edge','BEVEL');b.width=bevel;b.segments=3;o.modifiers.new('normal','WEIGHTED_NORMAL');return o
def disc(name,p,at,r,depth,m,rot=(math.pi/2,0,0)):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=depth);o=bpy.context.object;o.name=name;o.parent=p;o.location=at;o.rotation_euler=rot;o.data.materials.append(M[m]);b=o.modifiers.new('rim','BEVEL');b.width=.0018;b.segments=2;return o
def star(name,p,at,r,m):
 vs=[at]
 for i in range(10):
  a=math.pi/2+i*math.pi/5;d=r if i%2==0 else r*.46;vs.append((at[0]+math.cos(a)*d,at[1],at[2]+math.sin(a)*d))
 return mesh(name,p,vs,[(0,i+1,(i+1)%10+1) for i in range(10)],m,solid=.002)
def ribbon(name,p,pts,widths,m,depth=.005):
 # Catmull-Rom path interpolation; flat broad surface, subtle center ridge, sharp tips.
 path=[];ww=[]
 P=[Vector(v) for v in pts]
 for j in range(len(P)-1):
  a=P[max(0,j-1)];b=P[j];c=P[j+1];d=P[min(j+2,len(P)-1)]
  for k in range(8):
   t=k/8;path.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t));ww.append(widths[j]*(1-t)+widths[j+1]*t)
 path.append(P[-1]);ww.append(widths[-1]);vs=[];fs=[]
 for i,(v,w) in enumerate(zip(path,ww)):
  tangent=(path[min(i+1,len(path)-1)]-path[max(i-1,0)]).normalized();side=tangent.cross(Vector((0,-1,0))).normalized()
  if side.length<.1:side=Vector((1,0,0))
  for j in range(7):
   u=(j-3)/3;vs.append(tuple(v+side*w*u+Vector((0,-depth*(1-u*u),0))))
 for i in range(len(path)-1):
  for j in range(6):a=i*7+j;fs.append((a,a+1,a+8,a+7))
 return mesh(name,p,vs,fs,m,1,.001)
root=empty('kohaku');body=empty('body',root)
# Delicate head: broad calm forehead, shallow eye plane, small integrated nose, tapered chin.
head=empty('head',body,(0,0,1.49))
rings=[(0,.012,.025,-.022),(.012,.038,.041,-.016),(.035,.066,.058,-.002),(.062,.091,.071,.004),(.090,.108,.083,.012),(.12,.118,.090,.014),(.16,.122,.092,.017),(.20,.118,.092,.022),(.235,.093,.078,.025),(.261,.048,.052,.027),(.27,.004,.01,.026)]
vs=[];uv=[];fs=[];N=96
for z,rx,ry,cy in rings:
 for j in range(N):
  a=-math.pi+math.tau*j/N;x=rx*math.sin(a);y=cy-ry*math.cos(a)
  front=max(0,math.cos(a))**12
  # Nose is part of the facial mesh; no sphere attached to the face.
  nose=.026*math.exp(-(x/.014)**2-((z-.079)/.017)**2)+.006*math.exp(-(x/.013)**2-((z-.108)/.035)**2)
  y-=nose*front
  vs.append((x,y,z));uv.append((.5+x/.28,.14+z/.27*.86))
for k in range(len(rings)-1):
 for j in range(N):a=k*N+j;b=k*N+(j+1)%N;fs.append((a,b,b+N,a+N))
o=mesh('continuous_anime_face',head,vs,fs,'face',2,uv=uv);o.data.materials.append(M['skin'])
for f in o.data.polygons:
 center=sum((o.data.vertices[v].co for v in f.vertices),Vector())/len(f.vertices)
 if center.y>.018:f.material_index=1
for s in [-1,1]:
 ell('ear',head,(s*.119,.018,.102),(.015,.012,.030),'skin')
 curve('ear_inner',head,[(s*.123,.004,.12),(s*.127,.002,.105),(s*.121,.003,.09)],.002,'cloth_shadow')
 disc('ear_stud',head,(s*.123,-.004,.08),.004,.003,'gold')
 patch('coral_earring',head,[(s*.123,-.004,.078),(s*.139,-.003,.040),(s*.122,-.004,.047),(s*.112,-.004,.036)],'cloth',.002)
loft('neck',body,[(1.385,.060,.045,0,.015),(1.425,.042,.042,0,.014),(1.50,.042,.042,0,.020)],'skin',32,2)
# Skull-conforming cropped bob cap, open in front.
vs=[];fs=[];ns=96;nr=28
for i in range(nr+1):
 for j in range(ns):
  a=math.tau*j/ns;front=max(0,math.cos(a));limit=2.14-1.05*front**3;t=(i+.02)/(nr+.02)*limit
  vs.append((.132*math.sin(t)*math.sin(a),.029-.111*math.sin(t)*math.cos(a),.162+.131*math.cos(t)))
for i in range(nr):
 for j in range(ns):a=i*ns+j;b=i*ns+(j+1)%ns;fs.append((a,b,b+ns,a+ns))
mesh('cropped_hair_mass',head,vs,fs,'hair',1,.0015)
# Asymmetric wispy fringe; each lock has a designed tapered planar silhouette.
fringes=[([(-.035,-.023,.286),(-.067,-.089,.248),(-.10,-.111,.184),(-.112,-.104,.093)],[.024,.034,.023,.0006]),([(-.012,-.038,.287),(-.03,-.094,.239),(-.05,-.111,.187),(-.044,-.102,.143)],[.027,.032,.023,.0006]),([(.01,-.036,.288),(.008,-.096,.241),(.001,-.111,.19),(.015,-.111,.155)],[.025,.029,.018,.0004]),([(.028,-.033,.285),(.040,-.091,.245),(.053,-.112,.206),(.069,-.105,.168)],[.023,.031,.022,.0004]),([(.052,-.019,.282),(.077,-.079,.246),(.10,-.098,.211),(.116,-.094,.159)],[.022,.028,.018,.0005])]
for i,(pts,ws) in enumerate(fringes):
 ribbon('feathered_fringe',head,pts,ws,'hair_mid' if i%2==0 else 'hair',.003)
 # broad painted-style highlight surface at upper middle of lock
 ps=[Vector(x) for x in pts];hp=[tuple(ps[0].lerp(ps[1],.75)+Vector((0,-.003,0))),tuple(ps[1]+Vector((0,-.005,0))),tuple(ps[1].lerp(ps[2],.33)+Vector((0,-.006,0)))];ribbon('fringe_tonal_break',head,hp,[.002,ws[1]*.65,.001],'hair_light',.001)
for s in [-1,1]:
 for j in range(4):
  ribbon('tapered_side_hair',head,[(s*(.073+j*.013),.0+j*.02,.267),(s*(.119+j*.006),-.055+j*.017,.19),(s*(.125+j*.004),-.051+j*.020,.10),(s*(.111+j*.01),-.068+j*.016,.018-j*.008)],[.02,.024,.018,.0004],'hair_mid' if j==1 else 'hair',.003)
 # Fine few flyaways, not a forest of rounded strands.
 curve('flyaway',head,[(s*.05,.001,.289),(s*.134,-.009,.267),(s*.153,-.027,.19),(s*.148,-.034,.157)],.0008,'hair_mid')
for j in range(12):
 a=.45+j*(math.tau-.9)/11
 ribbon('nape_blade',head,[(.07*math.sin(a),.027-.05*math.cos(a),.276),(.128*math.sin(a),.03-.108*math.cos(a),.18),(.117*math.sin(a),.03-.095*math.cos(a),.095),(.108*math.sin(a),.022-.10*math.cos(a),.048+.009*math.sin(j))],[.021,.022,.019,.0003],'hair_mid' if j%4==0 else 'hair',.003)
pony=empty('pony_R',head,(.09,.096,.233));empty('pony_L',head)
ell('loose_bun_core',pony,(.007,.02,.008),(.066,.051,.069),'hair')
for j in range(10):
 a=j*math.tau/10
 pts=[(-.013,.008,.014),(.058*math.cos(a),.042,.078*math.sin(a)),(.075*math.cos(a),.076,.043*math.sin(a)-.028),(.067*math.cos(a)+.008,.041,-.083-j%3*.008)]
 ribbon('loose_bun_lock',pony,pts,[.010,.022,.019,.0005],'hair_mid' if j%3==0 else 'hair',.003)
for r,z,xx in [(.027,.247,.107),(.014,.204,.121)]:
 disc('music_ornament_mount',head,(xx,-.018,z),r+.003,.009,'gold');disc('music_ornament',head,(xx,-.025,z),r,.004,'pink' if r>.02 else 'teal');disc('ornament_recess',head,(xx,-.029,z),r*.73,.002,'cloth_shadow' if r>.02 else 'ink');curve('music_note',head,[(xx-.004,-.032,z-.005),(xx-.003,-.032,z+.009),(xx+.007,-.032,z+.003)],.0015,'ivory')
# Slim layered black top with open neckline, pendant.
loft('dark_inner_top',body,[(.98,.136,.083,0,0),(1.04,.125,.076,0,0),(1.17,.128,.092,0,0),(1.29,.147,.094,0,0),(1.37,.161,.076,0,.008),(1.395,.072,.055,0,.008)],'ink',48,2,solid=.002)
curve('necklace',body,[(-.05,-.051,1.425),(-.055,-.09,1.37),(0,-.099,1.335),(.055,-.09,1.37),(.05,-.051,1.425)],.0015,'gold')
patch('pendant',body,[(-.009,-.102,1.337),(0,-.104,1.316),(.009,-.102,1.337)],'metal')
# Long lightweight open parka, shaped shoulder and flared asymmetric hem.
loft('long_coral_parka',body,[(.625,.243,.155,0,.023),(.633,.246,.156,0,.023),(.73,.231,.143,0,.02),(.91,.21,.127,0,.012),(1.07,.181,.113,0,.008),(1.22,.186,.122,0,.013),(1.35,.206,.105,0,.018),(1.41,.178,.085,0,.021),(1.44,.100,.065,0,.015)],'cloth',64,2,opening=.59,solid=.003,fold=.005)
for s in [-1,1]:
 pts=[(s*.055,-.052,1.44),(s*.108,-.086,1.36),(s*.114,-.098,1.2),(s*.104,-.095,1.03),(s*.12,-.10,.85),(s*.137,-.106,.632)]
 curve('zipper_dark_tape',body,pts,.004,'lining');curve('zipper_teeth',body,[(x+s*.003,y-.003,z) for x,y,z in pts],.0011,'gold')
 for z in [.72,.84,.96,1.08,1.20,1.32]:disc('parka_snap',body,(s*(.114 if z>1 else .13),-.107,z),.0035,.002,'metal')
 # Flat fabric lapels rather than tubular collar rings.
 patch('folded_lapel',body,[(s*.052,-.052,1.44),(s*.091,-.075,1.465),(s*.164,-.087,1.383),(s*.132,-.124,1.32),(s*.092,-.107,1.366)],'cloth_lit',.003)
 curve('collar_seam',body,[(s*.085,-.081,1.451),(s*.148,-.09,1.38),(s*.128,-.12,1.337)],.0012,'cloth_shadow')
 curve('hood_drawcord',body,[(s*.112,-.105,1.394),(s*.13,-.131,1.272),(s*.122,-.133,1.216)],.0018,'ink')
 box('drawcord_aglet',body,(s*.122,-.134,1.208),(.006,.006,.02),'metal',.001)
 patch('angled_parka_pocket',body,[(s*.14,-.10,.93),(s*.181,-.068,.953),(s*.19,-.071,.84),(s*.149,-.108,.82)],'cloth_shadow')
 curve('pocket_welt',body,[(s*.14,-.108,.93),(s*.181,-.077,.953)],.003,'cloth_lit')
 # Hanging hem adjustment tape, purposeful and narrow.
 patch('parka_adjuster',body,[(s*.18,-.08,.76),(s*.19,-.078,.76),(s*.191,-.084,.53),(s*.18,-.087,.526)],'cloth_shadow')
 box('hem_buckle',body,(s*.186,-.09,.56),(.017,.004,.018),'ink',.002)
# Soft hood draped on the back, open bowl with a defined folded rim.
loft('draped_hood',body,[(1.23,.020,.025,0,.116),(1.25,.072,.040,0,.117),(1.32,.125,.072,0,.111),(1.42,.135,.082,0,.092),(1.458,.117,.078,0,.077)],'cloth',48,2,opening=.67,solid=.004)
curve('hood_rim',body,[(-.075,-.005,1.446),(-.119,.055,1.447),(-.073,.146,1.439),(0,.163,1.426),(.073,.146,1.439),(.119,.055,1.447),(.075,-.005,1.446)],.003,'cloth_lit')
# Crisp sewn pleats and waist belt.
vs=[];fs=[];n=96
for k,(z,rx,ry) in enumerate([(1.055,.139,.094),(1.022,.146,.098),(.755,.199,.126),(.743,.20,.127)]):
 for j in range(n):
  a=j*math.tau/n;f=(.006 if k>1 else .001)*math.cos(a*16);vs.append(((rx+f)*math.sin(a),-(ry+f)*math.cos(a),z))
for k in range(3):
 for j in range(n):a=k*n+j;b=k*n+(j+1)%n;fs.append((a,b,b+n,a+n))
mesh('tailored_pleated_skirt',body,vs,fs,'charcoal',solid=.002)
loft('waist_belt',body,[(1.035,.143,.098,0,0),(1.057,.142,.097,0,0)],'ink',64,0,solid=.003)
box('belt_buckle',body,(0,-.104,1.046),(.032,.006,.020),'metal',.003)
for s in [-1,1]:
 leg=empty('leg_L' if s<0 else 'leg_R',root,(s*.086,0,.96))
 loft('shaped_leg',leg,[(-.825,.032,.036,0,.008),(-.77,.034,.039,0,.012),(-.65,.045,.048,0,.025),(-.52,.049,.052,0,.020),(-.41,.038,.044,0,-.006),(-.35,.044,.045,0,-.006),(-.21,.059,.061,0,0),(-.05,.069,.068,0,0),(0,.069,.066,0,0)],'charcoal',40,2)
 loft('stocking_band',leg,[(-.235,.0595,.062,0,0),(-.207,.060,.063,0,0)],'ink',48,1,solid=.001)
 for z in [-.23,-.20]:curve('stocking_topstitch',leg,[(-.045,-.042,z),(0,-.064,z),(.045,-.042,z)],.001,'seam')
 patch('leg_garter',leg,[(s*.023,-.068,-.05),(s*.035,-.068,-.05),(s*.036,-.065,-.275),(s*.024,-.065,-.275)],'ink')
 box('garter_buckle',leg,(s*.03,-.070,-.18),(.017,.005,.021),'metal',.002)
 # Distinct shoe profile in XY outlines, not an oval atop a slab.
 outline=[(-.04,.055),(.04,.055),(.060,.010),(.065,-.115),(.045,-.175),(0,-.192),(-.047,-.18),(-.065,-.133),(-.061,-.02)]
 for name,zs,scale,m in [('sole',[(-.945,1),(-.93,1.02),(-.911,.99)],1,'ivory'),('outsole',[(-.954,.96),(-.943,1)],1,'sole'),('upper',[(-.913,.94),(-.875,.89),(-.836,.68)],1,'charcoal')]:
  v=[];f=[];N=len(outline)
  for z,q in zs:
   for x,y in outline:v.append((x*q,y*q,z))
  for k in range(len(zs)-1):
   for j in range(N):a=k*N+j;b=k*N+(j+1)%N;f.append((a,b,b+N,a+N))
  f.extend([tuple(reversed(range(N))),tuple((len(zs)-1)*N+j for j in range(N))]);mesh('sneaker_'+name,leg,v,f,m,2)
 loft('sneaker_ankle',leg,[(-.895,.045,.064,0,.005),(-.815,.047,.06,0,.01),(-.793,.041,.051,0,.012)],'ink',32,2,solid=.003)
 patch('shoe_tongue',leg,[(-.025,-.055,-.80),(.025,-.055,-.80),(.027,-.116,-.88),(-.027,-.116,-.88)],'cloth_shadow',.003)
 for j in range(5):
  y=-.065-j*.014;z=-.819-j*.012
  curve('pink_lace',leg,[(-.026,y,z),(0,y-.012,z+.001),(.026,y,z)],.0018,'pink')
 for side in [-1,1]:
  patch('sneaker_panel',leg,[(side*.055,-.125,-.898),(side*.057,-.027,-.892),(side*.046,.013,-.824),(side*.045,-.027,-.82),(side*.059,-.095,-.863)],'sole',.002)
  curve('shoe_panel_trim',leg,[(side*.059,-.126,-.897),(side*.061,-.035,-.89),(side*.049,.016,-.83)],.0015,'pink')
 box('cyan_heel_insert',leg,(0,.052,-.932),(.061,.009,.012),'teal',.003)
 box('heel_pull_tab',leg,(0,.052,-.802),(.018,.012,.04),'cloth_shadow',.003)
 # Sleeve section follows a gentle hanging arm with elbow shape.
 arm=empty('arm_L' if s<0 else 'arm_R',root,(s*.185,0,1.36))
 loft('parka_sleeve',arm,[(-.49,.050,.051,s*.045,-.022),(-.475,.063,.058,s*.055,-.018),(-.42,.088,.079,s*.075,-.007),(-.34,.075,.071,s*.064,.012),(-.24,.068,.068,s*.053,.024),(-.12,.081,.076,s*.035,.02),(0,.077,.068,0,.005),(.038,.038,.047,-s*.011,.013)],'cloth',40,2,fold=.007)
 loft('tailored_cuff',arm,[(-.509,.047,.044,s*.046,-.022),(-.48,.052,.049,s*.045,-.022),(-.472,.057,.052,s*.049,-.02)],'cloth_shadow',32,1,solid=.002)
 loft('fingerless_glove_wrist',arm,[(-.545,.037,.029,s*.045,-.024),(-.51,.040,.034,s*.046,-.024)],'ink',32,1)
 # Hand surface + tapered finger shapes; slender and relaxed.
 palm=loft('hand_palm',arm,[(-.597,.026,.016,s*.044,-.023),(-.573,.033,.021,s*.044,-.023),(-.537,.031,.022,s*.044,-.023)],'skin',32,2)
 for j,L in enumerate([.038,.051,.048,.035]):
  x=s*(.020+j*.015)
  loft('relaxed_finger',arm,[(-.584-L,.004,.004,x,-.032),(-.579-L*.7,.006,.006,x,-.03),(-.58,.0065,.007,x,-.024)],'skin',16,2)
 loft('thumb',arm,[(-.579,.005,.005,s*.005,-.04),(-.557,.010,.010,s*.013,-.04),(-.54,.010,.012,s*.023,-.033)],'skin',16,2)
 # Star patch and sleeve zip lie on front-facing surface.
 star('sleeve_star_border',arm,(s*.04,-.077,-.096),.025,'ink');star('sleeve_star_fill',arm,(s*.04,-.079,-.096),.020,'gold');star('sleeve_star_inner',arm,(s*.04,-.080,-.096),.012,'ivory')
 patch('sleeve_utility_pocket',arm,[(s*.009,-.067,-.142),(s*.071,-.067,-.142),(s*.072,-.059,-.255),(s*.016,-.061,-.255)],'cloth_shadow',.002)
 curve('sleeve_zip',arm,[(s*.027,-.07,-.15),(s*.03,-.064,-.24)],.0013,'metal')
 box('sleeve_zip_pull',arm,(s*.03,-.069,-.23),(.008,.004,.018),'ink',.001)
# Mic clipped at the belt; gives natural hands rather than a fused microphone grip.
disc('microphone_body',body,(.10,-.137,.954),.012,.12,'ink',rot=(0,.15,0));ell('microphone_grille',body,(.109,-.137,1.026),(.020,.020,.026),'metal')
for z in [1.011,1.02,1.03,1.039]:
 curve('grille_line',body,[(.093,-.149,z),(.109,-.157,z),(.125,-.149,z)],.001,'ink')
# Slim shoulder harness; keep the front silhouette uncluttered.
for s in [-1,1]:
 curve('harness',body,[(s*.14,-.099,1.16),(s*.16,-.097,1.34),(s*.139,.025,1.425),(s*.11,.131,1.32)],.007,'ink')
 box('harness_buckle',body,(s*.157,-.106,1.312),(.017,.005,.023),'metal',.002)
# Studio validation setup, neutral color management; no scene props hiding silhouette.
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.render.resolution_x=1100;sc.render.resolution_y=1300;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('Neutral studio');sc.world.color=(.35,.35,.35);sc.world.use_nodes=True;bg=sc.world.node_tree.nodes.get('Background');bg.inputs[0].default_value=(.62,.63,.65,1);bg.inputs[1].default_value=.35
sc.view_settings.view_transform='Standard';sc.view_settings.look='None'
for loc,power,size in [((-3,-4,5),320,5),((3,-2,3),180,4),((0,3,4),250,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.1,-5.5,2.2));cam=bpy.context.object;cam.name='ReviewCamera';cam.data.type='ORTHO';cam.data.ortho_scale=2.12;cam.rotation_euler=(Vector((0,0,.91))-cam.location).to_track_quat('-Z','Y').to_euler();sc.camera=cam
sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':a.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=root;root.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print('KOHAKU_V3_SOURCE',OUT)
