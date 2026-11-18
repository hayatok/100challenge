"""In-place sprint, dive and slide poses. Distances are in design-sheet pixels."""
from math import acos, atan2, cos, pi, radians, sin, sqrt

import numpy as np
from mathutils import Quaternion, Vector

from forms import M


def sample(t, keys):
    """Ease between the keyed body poses, with a short hold at either end."""
    for (a, start), (b, end) in zip(keys, keys[1:]):
        if t <= b:
            u = min(1, max(0, (t - a) / (b - a)))
            u = u * u * (3 - 2 * u)
            return tuple(x + (y - x) * u for x, y in zip(start, end))
    return keys[-1][1]


def support_geometry(surface):
    groups = {}
    for bone, point in zip(surface.bones, surface.verts):
        groups.setdefault(bone, []).append(point)
    return {name: np.asarray(points) / M for name, points in groups.items()}


def rotation(pitch=0, yaw_in=0, swivel=0):
    # Bring the outward A-pose towards the sagittal plane before pitching the arm.
    return (Quaternion((0, 0, 1), radians(swivel)) @
            Quaternion((1, 0, 0), radians(pitch)) @
            Quaternion((0, 1, 0), radians(yaw_in)))


def sport_pose(rig, bib, state, t, support):
    bones = rig.pose.bones
    world = {}
    joints = {}

    def orient(name, target, relative=False):
        bone = bones[name]
        parent = bone.parent
        parent_q = world[parent.name] if parent else Quaternion()
        world[name] = parent_q @ target if relative else target
        rest = bone.bone.matrix_local.to_quaternion()
        bone.rotation_quaternion = rest.inverted() @ parent_q.inverted() @ world[name] @ rest
        pivot = bone.bone.head_local / M
        if parent:
            joints[name] = joints[parent.name] + parent_q @ (pivot - parent.bone.head_local / M)
        else:
            joints[name] = pivot

    cycle = 2 * pi * t
    # Suzu opens her arms for balance. Rikka pitches further and keeps her
    # elbows close. An and Mio use a wider hand separation on impact.
    spread = (0, 10, -5, 6, -2, 5)[bib]
    lead = (1, -1, 1, -1, -1, 1)[bib]
    if state == 'sprint':
        y_shift = 0
        z_shift = -24 + 10 * sin(2 * cycle)
        hips = 7
        chest = (24, 21, 29, 25, 20, 23)[bib]
        head = 11 - 3.5 * sin(2 * cycle)
        sway = 5.5 * sin(cycle)
        follow = 8 * sin(2 * cycle - .95)
    else:
        # Body pitch is absolute so the character looks ahead while the chest
        # drops towards horizontal. The pelvis stays above the belly in flight.
        if state == 'dive':
            keys = [(0, (16, 32, 0, 0, -7, 0)), (.38, (62, 65, -12, 4, -12, -11)),
                    (.78, (83, 83, -19, 7, -13, 12)), (1, (82, 82, -16, 7, -13, 6))]
        else:
            keys = [(0, (82, 82, -16, 7, 0, 6)), (.19, (88, 78, -25, 8, 0, 16)),
                    (.43, (82, 77, -22, 8, 0, -9)), (.68, (67, 66, -16, 4, 0, -8)),
                    (.86, (39, 48, -6, 2, 0, 5)), (1, (12, 24, 2, 0, 0, 4))]
        hips, chest, head, y_shift, z_shift, follow = sample(t, keys)
        sway = -lead * 2 * sin(pi * t)
    orient('Pelvis', rotation(hips, 0, -sway * .28))
    orient('Chest', rotation(chest, 0, sway))
    orient('Head', rotation(head, -.35 * sway, -.34 * sway))
    trail = 0
    if state == 'dive':
        trail = sample(t, [(0, (0,)), (.65, (1,)), (1, (1,))])[0]
    elif state == 'slide':
        trail = sample(t, [(0, (1,)), (.55, (1,)), (.87, (.35,)), (1, (.12,))])[0]
    ponytail = 109 * trail if bib == 2 else 0
    orient('Ornament', rotation(follow + ponytail, .32 * follow, -.40 * follow), relative=True)
    orient('Blink', Quaternion(), relative=True)
    blink = 1.0 if state == 'slide' and .15 < t < .39 else .01
    bones['Blink'].scale = (blink,) * 3

    for side, sign in [('L', 1), ('R', -1)]:
        phase = (t + (.5 if sign < 0 else 0)) % 1
        if state == 'sprint':
            # Track the support shoe backwards underneath the body, then fold
            # the shin up to recover it beneath the opposite high knee.
            if phase < .26:
                u = phase / .26
                y = -53 + 112 * u
                rise = 15 * max(0, (u - .73) / .27) ** 2
                toe = 18 * max(0, (u - .73) / .27) ** 2
            else:
                u = (phase - .26) / .74
                y = 3 + 56 * cos(pi * u) - 15 * sin(pi * u) ** 2
                rise = 15 * (1 - u) + 55 * sin(pi * u) ** 1.25
                toe = 18 * (1 - u) - 21 * sin(pi * u)
            down = 79 + z_shift - rise
            reach = min(78.8, max(10, sqrt(y * y + down * down)))
            knee = acos((reach * reach - 39 * 39 - 40 * 40) / (2 * 39 * 40))
            thigh = atan2(y, down) - atan2(40 * sin(knee), 39 + 40 * cos(knee))
            thigh *= 180 / pi
            shin = thigh + knee * 180 / pi
            pump = cos(phase * 2 * pi - .08)
            arm = 11 + 55 * pump
            elbow = arm - 73 + 11 * sin(phase * 2 * pi)
            wrist = elbow - 4
            lift = 18 + .35 * spread
        elif state == 'dive':
            offset = lead * sign
            start = (-47, 98, -12, -40, -66, -77, 13) if offset == 1 else (27, 88, 11, 15, -37, -49, 18)
            # At full reach the fingers project past the face and both shoes trail.
            keys = [(0, start), (.45, (57 + 19 * offset, 114 + 14 * offset, 112, -90, -84, -84, 11)),
                    (.80, (87 + 9 * offset, 128 + 10 * offset, 157, -93, -90, -92, 13)),
                    (1, (94 + 5 * offset, 126 + 9 * offset, 161, -44, -69, -83, 12))]
            thigh, shin, toe, arm, elbow, wrist, lift = sample(t, keys)
        else:
            offset = lead * sign
            end = (-63, 22, -3, 38, -46, -48, 17) if offset == 1 else (31, 115, 114, -39, -97, -99, 21)
            plant = (-43, 66, 4) if offset == 1 else (89, 125, 145)
            keys = [(0, (94 + 5 * offset, 126 + 9 * offset, 161, -44, -69, -83, 12)),
                    (.20, (95 + 6 * offset, 119 + 8 * offset, 158, -51, -98, -96, 8)),
                    (.44, (91 + 4 * offset, 106 + 5 * offset, 162, -70, -96, -96, 5)),
                    (.67, (*plant, -38, -53, -73, 12)),
                    (.85, (-69 if offset == 1 else 46, 57 if offset == 1 else 121,
                            0 if offset == 1 else 125, -16, -44, -57, 16)), (1, end)]
            thigh, shin, toe, arm, elbow, wrist, lift = sample(t, keys)
        orient('Thigh.' + side, rotation(thigh))
        orient('Shin.' + side, rotation(shin))
        orient('Foot.' + side, rotation(toe))
        arm_in = sign * (lift - spread)
        orient('UpperArm.' + side, rotation(arm, arm_in))
        orient('Forearm.' + side, rotation(elbow, arm_in))
        orient('Hand.' + side, rotation(wrist, arm_in))
        braid = 116 * trail if bib == 4 else 0
        orient('Lock.' + side, rotation(follow * .75 + braid, sign * follow * .5), relative=True)

    if state in ('slide', 'dive'):
        # The terminal diving silhouette meets the simulated landing plane
        # at the same pose and height that starts the slide.
        floor = float('inf')
        for name, points in support.items():
            if name == 'Blink':
                continue
            vertical = np.asarray(world[name].to_matrix()[2])
            base = np.asarray(bones[name].bone.head_local / M)
            floor = min(floor, float(np.min(points @ vertical) - base @ vertical + joints[name].z))
        clearance = .09 * 255 * max(0, 1 - t / .6) ** 2 if state == 'dive' else 0
        z_shift = clearance - floor
    root = bones['Pelvis']
    root.location = root.bone.matrix_local.to_quaternion().inverted() @ (Vector((0, y_shift, z_shift)) * M)
