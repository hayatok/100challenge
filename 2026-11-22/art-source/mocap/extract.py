"""Extract two actor-specific gait cycles from CMU optical marker captures."""
import argparse
import json
from pathlib import Path
import numpy as np
import ezc3d

def extract(path, start, end, offset):
    source = ezc3d.c3d(str(path))
    labels = [s.split(':')[-1] for s in source['parameters']['POINT']['LABELS']['value']]
    points = source['data']['points'][:3].transpose(2, 1, 0) * .001
    def marker(name):
        data = points[start:end + 1, labels.index(name)]
        if not np.isfinite(data).all():
            raise ValueError(f'Missing data on {name}')
        return data
    pelvis = sum(marker(s) for s in ['LFWT','RFWT','LBWT','RBWT']) / 4
    forward = pelvis[-1] - pelvis[0]
    forward[2] = 0
    stride = np.linalg.norm(forward)
    forward /= stride
    right = np.cross(forward, [0,0,1])
    def forward_pitch(vector):
        return np.rad2deg(np.arctan2(vector @ forward, -vector[:,2]))
    def yaw(across):
        return np.rad2deg(np.arctan2(-(across @ forward), across @ right))
    def roll(across):
        return np.rad2deg(np.arctan2(across[:,2], across @ right))
    hips = (marker('RFWT') + marker('RBWT') - marker('LFWT') - marker('LBWT')) / 2
    shoulders = marker('RSHO') - marker('LSHO')
    back = (marker('RSHO') + marker('LSHO')) / 2 - pelvis
    u = np.linspace(0,1,len(pelvis))
    sway = (pelvis - pelvis[0] - u[:,None]*(pelvis[-1]-pelvis[0])) @ right
    tracks = [sway - sway.mean(), pelvis[:,2] - pelvis[:,2].mean(), yaw(hips), roll(hips),
              np.rad2deg(np.arctan2(back @ forward,back[:,2])), yaw(shoulders)-yaw(hips), roll(shoulders)-roll(hips)]
    for side in 'LR':
        upper = marker(side+'ELB') - marker(side+'SHO')
        lower = (marker(side+'WRA')+marker(side+'WRB'))/2 - marker(side+'ELB')
        ankle = marker(side+'ANK')
        shoe = marker(side+'TOE')-marker(side+'HEE')
        pitch = np.rad2deg(np.arctan2(-shoe[:,2],shoe @ forward))
        tracks.extend([-forward_pitch(upper), -(forward_pitch(lower)-forward_pitch(upper)),
                       (ankle-pelvis) @ forward / stride, ankle[:,2]-ankle[:,2].min(),
                       pitch-np.percentile(pitch,35)])
    angles = np.stack(tracks,axis=1)
    # Correct endpoint mismatch over a short window on either side of the seam.
    mismatch = angles[-1]-angles[0]
    angles += .5*(np.maximum(1-u/.14,0)-np.maximum(1-(1-u)/.14,0))[:,None]*mismatch
    phase = (np.arange(64)/64 + offset/(end-start)) % 1
    frames = np.stack([np.interp(phase,u,col) for col in angles.T],axis=1)
    return dict(stride=round(float(stride),5), values=frames.round(5).flatten().tolist())

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    data = dict(walk=extract(args.source/'16_16.c3d',110,256,0),
                run=extract(args.source/'16_35.c3d',45,142,50))
    args.output.write_text(json.dumps(data,separators=(',',':'))+'\n',encoding='utf-8')
