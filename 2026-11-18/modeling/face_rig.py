"""Build the cast's head-weighted facial relief and six editable expression poses."""
from functools import lru_cache
from math import cos, pi, sin, sqrt

import bpy
from face_paint import IRIS, MOUTH, SCLERA, ink_uv
from forms import CAST, EYES, M, profile

KEYS = ('Basis', 'Focus', 'Startle', 'Cheer', 'Blink', 'FocusBlink', 'StartleBlink')

# Eye widths, gaze offset, brow attitude and mouth placement follow the front art.
# The cast sheet poses the five rivals at an angle. Keep the small paired offsets
# without pushing an entire eye or mouth off the centred three-dimensional jaw.
EYE_WIDTHS = ((20.4,20.4),(18.,17.),(18.,16.5),(18.,16.5),(16.,16.),(17.5,18.))
EYE_HEIGHTS = ((16.3,16.3),(12.,12.),(12.,11.5),(15.,14.),(14.5,14.),(13.,13.5))
GAZE = (-.04,.06,.12,-.06,-.08,.13)
BROW_TILT = (3.6,1.3,4.0,3.1,1.4,2.1)
MOUTHS = (
    (1.,169.7,14.5,12.), (4.,190.7,15.,10.4),
    (3.,195.,13.,.85), (3.,191.6,14.,10.6),
    (3.,196.,10.,.85), (2.,190.,12.,4.2),
)


def clamp(value, lo, hi):
    return min(hi,max(lo,value))


def uv(pixel):
    return pixel[0]/1024, 1-pixel[1]/1024


class Face:
    def __init__(self, index):
        self.index = index
        self.cast = CAST[index]
        self.coords = {key: [] for key in KEYS}
        self.faces = []
        self.uvs = []
        self.regions = {}

    @lru_cache(maxsize=8192)
    def skin(self, x, row):
        """Invert the current cheek surface in the calibrated front reference."""
        c = self.cast
        x *= c['k']
        target = (c['floor']-row)*c['k']
        top, bottom = c['stations'][0][0], c['stations'][-1][0]
        base = clamp((row-top)/(bottom-top),0.,1.)
        theta = 0.
        v = base
        # Y is solved on the actual cheek at this X and Z. Jaw taper and the
        # crown-to-chin offset are independent of the hair envelope.
        for _ in range(3):
            side = 1 if x>=0 else -1
            lo,hi = 0., pi*.495
            for _ in range(12):
                t = (lo+hi)*.5
                if abs(profile(c,t*side,v)[0]) < abs(x):
                    lo=t
                else:
                    hi=t
            theta = side*(lo+hi)*.5
            px,py,pz = profile(c,theta,v)
            v = clamp(v+(pz-target)/((bottom-top)*c['k']),0.,1.)
        return x,py,target

    def point(self, x, row, relief):
        sx, sy, sz = self.skin(round(x,3),round(row,3))
        return sx*M, (sy-relief*self.cast['k'])*M, sz*M

    def grid(self, name, steps, rows, painter, shade, reverse=False):
        """One connected strip, sharing topology and UVs across every pose."""
        base = len(self.coords['Basis'])
        pixels = []
        for j in range(rows+1):
            v = j/rows
            for n in range(steps+1):
                u = -1+2*n/steps
                for key, vertices in self.coords.items():
                    vertices.append(self.point(*painter(key,u,v)))
                pixels.append(uv(shade(u,v) if callable(shade) else ink_uv(shade)))
        stride = steps+1
        for j in range(rows):
            for n in range(steps):
                a = j*stride+n
                corners = [a,a+1,a+1+stride,a+stride]
                if not reverse:
                    corners.reverse()
                self.faces.append([base+q for q in corners])
                self.uvs.append([pixels[q] for q in corners])
        self.regions.setdefault(name, []).extend(range(base,base+len(pixels)))


def mode(key):
    return key[:-5] if key in ('FocusBlink','StartleBlink') else key


class Eye:
    def __init__(self, face, side_index):
        self.face = face
        i = face.index
        self.side = (-1,1)[side_index]
        source_x,source_y,_,_ = EYES[i][side_index]
        dx = source_x-CAST[i]['cx']
        # Turn the asymmetric illustration onto the rounded model.
        self.cx = dx*(.89 if i else 1.)
        mean_row = (EYES[i][0][1]+EYES[i][1][1])*.5
        self.cy = mean_row+.70*(source_y-mean_row)
        self.w = EYE_WIDTHS[i][side_index]
        self.h = EYE_HEIGHTS[i][side_index]
        self.gaze = GAZE[i] * self.side
        self.tilt = (6.9,8.3)[side_index] if i==0 else BROW_TILT[i]

    def shape(self, key, u):
        state = mode(key)
        width = self.w * (1.04 if state=='Cheer' else .98 if state=='Startle' else 1)
        u0 = clamp(u,-1.,1.)
        arch = max(.001,1-u0*u0)
        closed = key in ('Blink','FocusBlink','StartleBlink','Cheer') or (key=='Basis' and self.face.index==1)
        if closed:
            peak = 6.6 if state=='Cheer' or self.face.index==1 else 3.5
            mid = self.cy + 2.8 - peak*arch - 1.65*u
            epsilon=.012*arch if self.face.index==1 and key=='Basis' else 0.
            top = mid-epsilon
            bottom = mid+epsilon
        else:
            incline = 4.2 if state=='Focus' else 1. if state=='Startle' else 2.5
            mid = self.cy - incline*u + (.8 if state=='Focus' else -.8 if state=='Startle' else 0)
            upper = .46 if state=='Focus' else 1.03 if state=='Startle' else .89
            lower = .62 if state=='Focus' else 1.02 if state=='Startle' else .97
            top = mid - self.h*upper*arch**.71
            bottom = mid + self.h*lower*arch**.59
        return self.cx+self.side*width*u,top,bottom,closed

    def ocular_depth(self, u, v, closed):
        dome = max(0., 1-u*u) * max(0.,1-(2*v-1)**2)
        # Fold the cornea into the upper lash. Keeping its depth near the
        # surface during interpolation prevents the cheek clipping a half smile.
        return 2.22 if closed else 2.10 + 3.1*dome

    @lru_cache(maxsize=1024)
    def socket(self,x):
        # A cornea remains smooth where a rounded cheek rolls away below it.
        # Fit its supporting plane to just the vertical span of this eye slice.
        u=clamp((x-self.cx)*self.side/self.w,-1.,1.)
        centre=self.cy-2.1*u
        span=2.8+1.05*self.h*sqrt(max(0.,1-u*u))
        rows=[centre+span*(j/4-1) for j in range(9)]
        depths=[self.face.skin(x,round(h,3))[1] for h in rows]
        slope=(depths[-1]-depths[0])/(2*span)
        intercept=min(y-slope*(row-centre) for row,y in zip(rows,depths))
        return centre,intercept,slope

    def orbital(self,x,row,relief):
        x=round(x,3)
        _,sy,_=self.face.skin(x,round(row,3))
        centre,intercept,slope=self.socket(x)
        correction=(sy-intercept-slope*(row-centre))/self.face.cast['k']
        return x,row,relief+clamp(correction,0.,7.3)

    def sclera(self,key,u,v):
        x,top,bottom,closed = self.shape(key,u)
        return self.orbital(x,top+(bottom-top)*v-(.72*(1-u*u) if closed else 0.),self.ocular_depth(u,v,closed))

    def iris_bounds(self,key,u):
        state=mode(key)
        radius=.52 if state=='Startle' else .64
        centre=self.gaze+(.055 if state=='Focus' else 0)
        eye_u=centre+u*radius
        x,top,bottom,closed=self.shape(key,eye_u)
        # Share this boundary with the four surrounding white panels. Their
        # triangles cannot cross the iris at steeply curved outer corners.
        mid=self.cy+(.45 if state=='Startle' else .9)
        height=self.h*(.77 if state=='Startle' else 1.16)*sqrt(max(0.,1-u*u))
        y0=clamp(mid-height,top,bottom)
        y1=clamp(mid+height,top,bottom)
        return eye_u,x,top,bottom,y0,y1,closed

    def white_end(self,key,u,v,outer):
        limit=self.iris_bounds(key,1. if outer else -1.)[0]
        t=(1+sin(pi*u/2))*.5
        eye_u=limit+(1-limit)*t if outer else -1+(limit+1)*t
        return self.sclera(key,eye_u,v)

    def white_margin(self,key,u,v,lower):
        eye_u,x,top,bottom,y0,y1,closed=self.iris_bounds(key,u)
        row=y1+(bottom-y1)*v if lower else top+(y0-top)*v
        eye_v=(row-top)/max(.001,bottom-top)
        return self.orbital(x,row-(.72*(1-eye_u*eye_u) if closed else 0.),self.ocular_depth(eye_u,eye_v,closed))

    def iris(self,key,u,v):
        eye_u,x,top,bottom,y0,y1,closed=self.iris_bounds(key,u)
        row=y0+(y1-y0)*v
        eye_v=(row-top)/max(.001,bottom-top)
        relief=self.ocular_depth(eye_u,eye_v,closed)
        if not closed:
            relief+=.89*(1-u*u)*sin(pi*v)
        return self.orbital(x,row-(.72*(1-eye_u*eye_u) if closed else 0.),relief)

    def iris_uv(self,u,v):
        x0,y0,x1,y1=IRIS
        vertical=(2*v-1)*sqrt(max(.002,1-u*u))
        return x0+(.5+.5*self.side*u)*(x1-x0), y0+(.5+.5*vertical)*(y1-y0)

    def upper_lid(self,key,u,v):
        # One lash runs from the tear duct to the raised, tapered outer wing.
        # Its lower edge touches the same aperture used by the ocular surface.
        t=(u+1)*.5
        corner=.82
        if t<=corner:
            eye_u=-1+2*t/corner
            x,row,_,closed=self.shape(key,eye_u)
            strength=3.05 if mode(key)=='Focus' else 2.30 if closed else 2.95
            thick=strength*(.06+(1-eye_u*eye_u)**.63+.39*(eye_u+1))
            if self.face.index==0 and not closed:
                thick*=1.16+.18*eye_u
            outer=clamp((eye_u-.48)/.52,0,1)
            thick+=1.45*outer**1.7
        else:
            wing=(t-corner)/(1-corner)
            x,row,_,closed=self.shape(key,1.)
            length=5.3 if self.face.index==0 else 3.9
            x+=self.side*length*wing
            row-=3.6*wing
            strength=3.05 if mode(key)=='Focus' else 2.30 if closed else 2.95
            weight=strength*.84*(1.34 if self.face.index==0 and not closed else 1.)
            thick=(weight+1.45)*(1-wing)**.78
        return self.orbital(x,row+(v-.86)*thick,2.65+.20*sin(pi*v))

    def white_uv(self,u,v,end=None,lower=None):
        key='Startle' if self.face.index==1 else 'Basis'
        if end is not None:
            limit=self.iris_bounds(key,1. if end else -1.)[0]
            f=(1+sin(pi*u/2))*.5
            eye_u=limit+(1-limit)*f if end else -1+(limit+1)*f
            eye_v=v
        else:
            eye_u,_,top,bottom,y0,y1,_=self.iris_bounds(key,u)
            row=y1+(bottom-y1)*v if lower else top+(y0-top)*v
            eye_v=(row-top)/max(.001,bottom-top)
        x0,y0,x1,y1=SCLERA
        return x0+(.5+.5*eye_u)*(x1-x0),y0+eye_v*(y1-y0)

    def brow(self,key,u,v):
        state=mode(key)
        arch=(1-u*u)
        x=self.cx+self.side*(u*self.w*.87-.65)
        high=8.2 if state=='Startle' else -.5 if state=='Focus' else 2.9 if state=='Cheer' else 0.
        slant=(self.tilt+2.2 if state=='Focus' else -1.8 if state=='Startle' else .8 if state=='Cheer' else self.tilt)
        row=self.cy-self.h-5.-high-3.4*arch-slant*u
        thick=(.13+arch**.6*2.8)*(1-.16*u)
        if self.face.index==0:
            row-=1.5 if self.side>0 else .15
            thick*=1.66
        return x,row+(v-.5)*thick,1.35+.24*sin(pi*v)

    def build(self):
        f=self.face
        flip=self.side<0
        for outer in (False,True):
            f.grid('Eyes',6,6,lambda k,u,v: self.white_end(k,u,v,outer),
                   lambda u,v:self.white_uv(u,v,end=outer),flip)
        for lower in (False,True):
            f.grid('Eyes',18,3,lambda k,u,v: self.white_margin(k,u,v,lower),
                   lambda u,v:self.white_uv(u,v,lower=lower),flip)
        f.grid('Irises',18,7,self.iris,self.iris_uv,flip)
        f.grid('Upper lashes',40,2,self.upper_lid,'lash',flip)
        f.grid('Brows',14,2,self.brow,'brow',flip)
        self.socket.cache_clear()


def mouth(face):
    i=face.index
    cx,cy,width,opening=MOUTHS[i]
    def profile_at(key,u):
        m=mode(key)
        arch=max(.001,1-u*u)
        centre_row=cy
        if m=='Startle':
            w,h,smile=7.2,9.3,-.3
            centre_row-=1.0
        elif m=='Cheer':
            w,h,smile=width+3.7,9.6,3.35
            centre_row-=2.8
            if i==0:
                h=13.0
                centre_row+=1.4
        elif m=='Focus':
            w,h,smile=11.5,1.45,1.65
        else:
            w,h,smile=width,opening,2.7
        x=cx+u*w
        middle=centre_row+smile*arch+(.9*u if i in (2,5) else 0)
        return x,middle-h*arch**.61*.62,middle+h*arch**.77
    def wall(key,u,v):
        x,y0,y1=profile_at(key,u)
        state=mode(key)
        # V follows anatomy. Surprise uncovers more cavity and less tooth;
        # a narrow grin draws the cheek up without an intersecting tooth plane.
        exposed=.065 if state=='Startle' else .34 if state=='Focus' else .23
        tongue=.74 if state=='Startle' else .54 if state=='Focus' else .48
        if v<.25:
            t=v/.25*exposed
        elif v<.53:
            t=exposed+(v-.25)/.28*(tongue-exposed)
        else:
            t=tongue+(v-.53)/.47*(1-tongue)
        hollow=(1-u*u)*sin(pi*t)
        tongue_round=max(0.,sin(pi*(t-tongue)/(1-tongue))) if t>=tongue else 0.
        depth=2.15-.72*hollow+.72*(1-u*u)*tongue_round
        return x,y0+(y1-y0)*t,depth
    def mouth_uv(u,v):
        x0,y0,x1,y1=MOUTH
        return x0+(.5+.5*u)*(x1-x0), y0+v*(y1-y0)
    face.grid('Mouth',24,12,wall,mouth_uv)


def spectacle_frames(face):
    # Dusty rose acetate has a raised pale bevel around the dark inner rim.
    # The temple arms on the body carry the frames back to the ears.
    frames=[]
    for j,side in enumerate((-1,1)):
        eye=Eye(face,j)
        def point(t, radius=1., eye=eye):
            def squircle(a):
                return (1 if a>=0 else -1)*abs(a)**.78
            return (eye.cx+23.5*radius*squircle(cos(t)),
                    eye.cy+.8+19.5*radius*squircle(sin(t))-2.3*cos(t))
        frames.append(point)
        def band(inner,outer,depth0,depth1,point=point):
            def coords(key,u,v):
                x,y=point(pi*(u+1),inner+(outer-inner)*v)
                return x,y,depth0+(depth1-depth0)*v
            return coords
        # Adjacent bevels make a single raised acetate cross-section. Stacking
        # coloured rings on top of one another breaks up at gameplay distance.
        for a,b,d0,d1,color in (
            (.898,.934,9.8,12.0,'frame_shadow'),(.934,1.005,12.0,12.6,'frame'),
            (1.005,1.070,12.6,12.0,'frame_light'),(1.070,1.095,12.0,9.8,'frame')):
            face.grid('Spectacles',48,1,band(a,b,d0,d1),color,True)
    x0,y0=frames[0](0)
    x1,y1=frames[1](pi)
    def bridge(key,u,v):
        t=(u+1)*.5
        return x0+(x1-x0)*t,y0+(y1-y0)*t-4.8*sin(pi*t)+(v-.5)*3.6,12.2+sin(pi*t)*2
    face.grid('Spectacles',14,2,bridge,'frame_light')


def build_face(index, rig, material):
    face=Face(index)
    Eye(face,0).build()
    Eye(face,1).build()
    mouth(face)
    if index==4:
        spectacle_frames(face)
    name='FaceRig_'+CAST[index]['name']
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(face.coords['Basis'], [], face.faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    layer=mesh.uv_layers.new(name='Albedo')
    for polygon,uvs in zip(mesh.polygons,face.uvs):
        polygon.use_smooth=True
        for loop,pixel in zip(polygon.loop_indices,uvs):
            layer.data[loop].uv=pixel
    obj.vertex_groups.new(name='Head').add(range(len(mesh.vertices)),1.,'REPLACE')
    for feature,vertices in face.regions.items():
        obj.vertex_groups.new(name=feature).add(vertices,1.,'REPLACE')
    obj.shape_key_add(name='Basis')
    for key in KEYS[1:]:
        block=obj.shape_key_add(name=key,from_mix=False)
        block.data.foreach_set('co',[v for point in face.coords[key] for v in point])
        block.value=0.0
    arm=obj.modifiers.new(name='Follow head',type='ARMATURE')
    arm.object=rig
    obj.parent=rig
    face.skin.cache_clear()
    return obj
