"""Measurements in design-sheet pixels (at 1250px width). Blender units are metres."""
# Horizontal stations of the head envelope, taken from turnaround front (01)
# and the cast sheet (02–06). Widths exclude appendages with their own rig.
CAST = [
 dict(name="Nagi", cx=273, floor=398, k=1, stations=[(21,8),(25,31),(36,57),(53,76),(74,90),(99,100),(124,108),(147,110),(164,112),(180,105),(191,95),(198,67)], hair="#38284f", bright="#63537d", jacket="#fbeddc", sleeve="#d9313d", pants="#34374e", shoe="#db3d4e", sock="#cc3546", skin="#ffcdad", iris="#b56a24"),
 dict(name="Suzu", cx=346, floor=389, k=1.09, stations=[(72,8),(76,29),(87,55),(101,70),(119,81),(140,89),(159,93),(178,90),(194,87),(206,74),(215,56)], hair="#e5b591", bright="#fff0cc", jacket="#397a50", sleeve="#3f8055", pants="#323a50", shoe="#a5b83c", sock="#5d9b62", skin="#c98c60", iris="#734527"),
 dict(name="Rikka", cx=557, floor=389, k=1.07, stations=[(67,8),(72,31),(83,50),(99,67),(120,75),(142,79),(161,78),(182,73),(200,67),(210,50),(218,31)], hair="#9575b1", bright="#ccb0ed", jacket="#603c88", sleeve="#64418e", pants="#6a468e", shoe="#8666ae", sock="#b7a1ce", skin="#ffddc9", iris="#8546a1"),
 dict(name="An", cx=745, floor=389, k=1.07, stations=[(50,8),(55,30),(66,51),(84,69),(102,80),(121,88),(142,94),(158,99),(177,94),(193,88),(208,74),(216,51)], hair="#d76220", bright="#ffad4a", jacket="#f3ad27", sleeve="#f8eee2", pants="#494150", shoe="#efaf24", sock="#f5b624", skin="#ffcd9e", iris="#b45d20"),
 dict(name="Nene", cx=946, floor=389, k=1.08, stations=[(56,7),(60,33),(72,55),(90,71),(112,83),(133,91),(151,95),(170,95),(189,89),(204,79),(215,60),(220,36)], hair="#b34c66", bright="#e7869e", jacket="#b06a83", sleeve="#93435e", pants="#553a4b", shoe="#9f4c65", sock="#bd7792", skin="#ffdac1", iris="#ae5065"),
 dict(name="Mio", cx=1137, floor=389, k=1.08, stations=[(47,8),(51,30),(62,49),(79,66),(99,80),(121,88),(143,93),(165,91),(184,84),(200,71),(211,51),(217,32)], hair="#32475e", bright="#6e879d", jacket="#435594", sleeve="#42569d", pants="#424561", shoe="#5579ae", sock="#7484bd", skin="#ffcfad", iris="#596c96"),
]
M = 1/255
EYES = [[(242,144,15,15),(305,142,16,16)],[(321,170,17,8),(389,166,16,8)],[(537,172,17,13),(595,179,13,12)],[(725,175,17,15),(786,168,13,15)],[(923,180,14,14),(982,172,15,15)],[(1107,171,15,14),(1169,161,17,15)]]
# Safe polygons exclude accessories, backgrounds and hands belonging to the posed key art.
FRONT_MASKS = [
 None,
 [(253,148),(274,105),(303,82),(342,72),(384,80),(414,103),(433,134),(438,177),(422,203),(393,210),(378,217),(338,218),(308,202),(292,212),(263,198),(249,188)],
 [(480,131),(503,88),(549,69),(580,72),(606,87),(630,119),(635,156),(624,194),(605,210),(578,218),(548,212),(516,204),(491,193),(479,173)],
 [(648,145),(676,91),(706,65),(752,53),(786,67),(817,92),(827,126),(843,158),(835,190),(815,209),(783,213),(757,219),(728,211),(700,201),(691,185),(665,194),(650,181)],
 [(851,145),(876,90),(909,65),(946,57),(977,60),(1005,79),(1026,112),(1037,149),(1034,180),(1014,203),(984,213),(947,220),(913,211),(879,203),(853,189)],
 [(1046,143),(1071,90),(1102,61),(1138,48),(1169,52),(1200,68),(1220,99),(1231,130),(1229,157),(1216,190),(1192,202),(1165,211),(1138,216),(1107,209),(1077,197),(1056,183)]
]
PALETTE = ['hair','bright','jacket','sleeve','pants','shoe','sock','skin','iris',
 '#fff3e2','#2e324b','#cfbba9','#efb946','#d66676','#6a3650','#df493e','#7b283c',
 '#f1dec8','#f3d3bf','#fff8e8','#353140','#986a68','#c7b7c0','#f0ceb0','#f6e0ce',
 '#795063','#fff0bf','#757180','#e76f65','#f9c752','#e8dbec','#805257']
from math import sin, cos, pi, exp
def station_width(c, y):
    stations = c['stations']
    for (a,ra),(b,rb) in zip(stations,stations[1:]):
        if y <= b:
            return ra+(rb-ra)*max(0,(y-a)/(b-a))
    return stations[-1][1]

# Side silhouette samples, registered to the ankle at x=603 on the 1,250 px sheet.
# The bangs project past the nose. Behind them the cheeks taper towards the neck.
NAGI_SIDE = [(21,603,632),(35,570,682),(55,548,704),(75,534,716),
             (100,526,726),(119,526,730),(128,532,731),(136,548,731),
             (147,550,730),(158,545,726),(168,547,721),(181,554,708),
             (191,568,694),(198,583,677)]

def side_edges(y):
    for (a,front,rear),(b,next_front,next_rear) in zip(NAGI_SIDE,NAGI_SIDE[1:]):
        if y<=b:
            t=max(0,(y-a)/(b-a))
            return front+(next_front-front)*t,rear+(next_rear-rear)*t
    return NAGI_SIDE[-1][1:]

def hair_profile(c, theta, v):
    """Surface in design pixels; +Y is rear, +X the subject's left."""
    top, bottom=c['stations'][0][0],c['stations'][-1][0]
    sy=top+(bottom-top)*v
    r=station_width(c,sy)*c['k']
    f=cos(theta)
    x=r*sin(theta)
    # Profile sheet puts the rear occiput behind the shoulder and recesses the chin.
    front=(.87-.21*v*v)*r
    rear=(.99+.04*v)*r
    y=15-(front if f>=0 else rear)*f
    if c is CAST[0]:
        face,occiput=side_edges(sy)
        centre=(face+occiput)*.5
        y=centre-603-(occiput-face)*.5*f
        # The forward eye belongs to the independent face. Across the
        # side of the bob the hair sweeps smoothly past the temporal bone.
        if f>0:
            band=exp(-((sy-151)/40)**2)
            y+=2.6*sin(2*abs(theta))*band
        # The illustrated fringe curves around the cheeks below the ears.
        x*=1-.040*(.6+.4*cos(theta)**2)
    if f>0:
        y-=3*exp(-(theta/.16)**2-((v-.77)/.08)**2)
    z=(c['floor']-sy)*c['k']
    z+=(max(f,0)**2*7-2*cos(theta*13))*(v**5)
    if f<.37:
        amp=(1-max(f,0)/.37)*(.45+1.9*v)*sin(13*theta+.9*(1-v))
        x+=sin(theta)*amp
        y-=cos(theta)*amp
    return x,y,z

def profile(c, theta, v):
    """Face surface. A separate scalp and individual locks surround this volume."""
    top, bottom = c['stations'][0][0], c['stations'][-1][0]
    sy = top + (bottom - top) * v
    k = c['k']
    r = station_width(c, sy) * k
    front = max(0, cos(theta))
    # A rounded jaw rolls under the cheek into the neck well before the bob ends.
    jaw = max(0, (v - .79) / .21)
    width = r * (.83 - .46 * jaw ** 1.35)
    if c is CAST[0]:
        # Measured visible half-widths on the frontal sheet: at rows
        # 170/180/186/190 the cheek spans 50/42/29/12 px. A rounded chin
        # needs a closed ellipsoidal end, not a wide, flat final ring.
        face_row=21+171*v
        blend=max(0,min(1,(face_row-143)/20))
        blend=blend*blend*(3-2*blend)
        cheek_row=max(0,(face_row-163)/29)
        chin_radius=54.2*max(.00006,1-cheek_row**2)**.5
        width=width*(1-blend)+chin_radius*blend
    x = width * sin(theta)
    if c is CAST[0]:
        # The short nose and brow sit in front of the forehead. The broad
        # cheek rounds toward the point of the chin in both orthogonal views.
        planes = ((21,5),(55,-24),(84,-39),(107,-47),(128,-53),
                  (148,-57),(160,-56),(172,-54),(182,-47),(188,-38),(192,-29))
        near = planes[-1][1]
        for (a,f),(b,g) in zip(planes,planes[1:]):
            if face_row <= b:
                near = f + (g-f)*max(0,(face_row-a)/(b-a))
                break
        depth=(7-near)*min(1,width/53.5)**.82
        y=near+depth*(1-cos(theta))
    else:
        depth = r * (.84 - .14 * v * v)
        y = 11 - depth * cos(theta)
    cheek = exp(-((abs(theta) - .53) / .35) ** 2 - ((v - .82) / .105) ** 2)
    y -= 5.8 * cheek * front
    y += 4.5 * jaw * jaw * front
    z = (c['floor'] - sy) * k + (5.7 + 8.5 * sin(theta) ** 2) * v ** 6
    if c is CAST[0]:z=c['floor']-face_row
    z -= 19 * max(0,1-v/.37)**2
    return x, y, z
