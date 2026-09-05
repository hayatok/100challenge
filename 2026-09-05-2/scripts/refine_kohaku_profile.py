"""Review correction: side-view hair volume, supported nose profile and open neck ends."""
import bpy,os,math,bmesh
from mathutils import Vector
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.open_mainfile(filepath=R+'/art/source/kohaku-v3.blend')
# Hair ribbons wrap around the skull, so they have width from the side as well.
for o in bpy.data.objects:
 if o.type!='MESH':continue
 if not any(o.name.startswith(s) for s in ['feathered_fringe','tapered_side_hair','nape_blade']):continue
 vs=list(o.data.vertices);rows=len(vs)//7
 if len(vs)%7:continue
 centers=[sum((v.co.copy() for v in vs[i*7:i*7+7]),Vector())/7 for i in range(rows)]
 for i,c in enumerate(centers):
  tangent=(centers[min(i+1,rows-1)]-centers[max(i-1,0)]).normalized()
  if o.name.startswith('feathered_fringe'):angle=0
  else:angle=math.atan2(c.x,-c.y+.025)
  normal=Vector((math.sin(angle),-math.cos(angle),0));side=tangent.cross(normal).normalized()
  w=(vs[i*7+6].co-vs[i*7].co).length/2
  if o.name.startswith('feathered_fringe'):c.y+=.017*math.sin(math.pi*i/(rows-1)*.7)
  for j,v in enumerate(vs[i*7:i*7+7]):
   u=(j-3)/3;v.co=c+side*w*u+normal*.003*(1-u*u)
# Replace the sparse control cage with a dense continuous facial profile.
old=bpy.data.objects['continuous_anime_face'];oldmesh=old.data;materials=list(oldmesh.materials)
rings=[(0,.012,.025,-.022),(.012,.038,.041,-.016),(.035,.066,.058,-.002),(.062,.091,.071,.004),(.090,.108,.083,.012),(.12,.118,.090,.014),(.16,.122,.092,.017),(.20,.118,.092,.022),(.235,.093,.078,.025),(.261,.048,.052,.027),(.27,.004,.01,.026)]
vs=[];uv=[];fs=[];N=96;Z=70
for k in range(Z+1):
 z=.27*k/Z
 n=next((j for j in range(len(rings)-1) if rings[j][0]<=z<=rings[j+1][0]),len(rings)-2);a,b=rings[n:n+2];t=(z-a[0])/(b[0]-a[0]);rx,ry,cy=[a[j]*(1-t)+b[j]*t for j in [1,2,3]]
 for j in range(N):
  angle=-math.pi+math.tau*j/N;x=rx*math.sin(angle);y=cy-ry*math.cos(angle)
  front=max(0,math.cos(angle))**12
  nose=.026*math.exp(-(x/.011)**2-((z-.079)/.011)**2)+.004*math.exp(-(x/.009)**2-((z-.105)/.028)**2)
  vs.append((x,y-nose*front,z));uv.append((.5+x/.28,.14+z/.27*.86))
for k in range(Z):
 for j in range(N):a=k*N+j;b=k*N+(j+1)%N;fs.append((a,b,b+N,a+N))
me=bpy.data.meshes.new('supported_face_profile');me.from_pydata(vs,[],fs);me.update();old.data=me
for m in materials:me.materials.append(m)
u=me.uv_layers.new(name='UVMap')
for l in me.loops:u.data[l.index].uv=uv[l.vertex_index]
for f in me.polygons:
 f.use_smooth=True
 if sum(me.vertices[v].co.y for v in f.vertices)/len(f.vertices)>.018:f.material_index=1
for mod in old.modifiers:
 if mod.type=='SUBSURF':mod.levels=1;mod.render_levels=1
# Avoid pinched ngon caps at the hidden ends of a smooth neck cylinder.
neck=bpy.data.objects['neck'];bm=bmesh.new();bm.from_mesh(neck.data);bmesh.ops.delete(bm,geom=[f for f in bm.faces if len(f.verts)>4],context='FACES');bm.to_mesh(neck.data);bm.free()
# Keep anime skin shading light; the tiny nose must not cast a broad realistic shadow.
for name in ['skin','face_painted']:
 m=bpy.data.materials[name];ramp=next(n for n in m.node_tree.nodes if n.type=='VALTORGB')
 for e in ramp.color_ramp.elements:e.color=(.95+(e.position+.15)/.8*.05,.91+(e.position+.15)/.8*.09,.92+(e.position+.15)/.8*.08,1)
bpy.ops.wm.save_as_mainfile(filepath=R+'/art/source/kohaku-v3.blend')
