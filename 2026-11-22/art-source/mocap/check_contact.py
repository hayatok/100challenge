"""Compare ideal sole-target drift in straight steady locomotion, before transform damping and IK."""
import json
from pathlib import Path
import numpy as np

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('cycles', type=Path)
data = json.loads(parser.parse_args().cycles.read_text())
for gait, speed, stride, begin, end in [('walk',1.27,.72+.60*(1.27-.5)/2.05,.115,.45),
                                         ('run',3.5,1.59,.12,.26)]:
    frames = np.array(data[gait]['values']).reshape(64,17)
    for index in range(2):
        channel = 9+5*index
        contact = []
        old = []
        maximum_overreach = 0
        for step in np.arange(begin,end-.045,1/512):
            phase = (step-.5*index)%1
            values = np.array([np.interp(phase,np.arange(65)/64,np.r_[column,column[0]])
                               for column in frames.T])
            angle = np.deg2rad(np.clip(values[channel+2],-28,65))
            yaw = np.deg2rad(5)
            sine, cosine = np.sin(angle),np.cos(angle)
            radius = np.hypot(.017*cosine,.124*sine)
            sy = -.052-.017**2*cosine/radius
            sz = .056+.124**2*sine/radius
            contact_z = (sy*sine+sz*cosine)*np.cos(yaw)
            contact_y = sy*cosine-sz*sine
            root = stride*step
            if not contact:
                locked = root+stride*values[channel]+.013+contact_z
            ankle_z = locked-root-contact_z
            contact.append(root+ankle_z+contact_z)
            hip_y = .96-.055+values[1]-(.068 if gait=='walk' else .094)
            maximum_overreach = max(maximum_overreach,np.hypot(hip_y+contact_y,ankle_z)-(.39+np.hypot(.445,.012)-.001))
            stance = .59 if gait=='walk' else .49
            extent = min(stride*stance*.42,.27 if gait=='walk' else .30)
            old.append(root+extent*(1-2*step/stance)+.013+.056*np.cos(yaw))
        print(f'{gait} {"LR"[index]}: old {np.ptp(old)*1000:.2f} mm, anchored {np.ptp(contact)*1000:.2f} mm, sagittal reach excess {maximum_overreach*1000:.2f} mm')

