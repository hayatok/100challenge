"""Body poses for the six racers, authored in design-sheet pixels at 30 fps."""
from math import cos, pi, radians, sin, sqrt

import numpy as np
from mathutils import Quaternion, Vector

from forms import M
from sport_poses import rotation, sample, sport_pose


PERFORMANCE_CLIPS = {
    'idle': 60, 'ready': 90, 'launch': 9,
    'run': 20, 'sprint': 16, 'jump': 24, 'land': 5,
    'stumble': 15, 'fall': 25, 'dive': 9, 'slide': 21,
    'finish': 78, 'finish_win': 78,
}
SIDES = (('L', 1), ('R', -1))
LEAD = (1, -1, 1, -1, 1, -1)


class Pose:
    """Set bone orientation in model space and solve wrist and ankle reach."""

    def __init__(self, rig, support):
        self.bones = rig.pose.bones
        self.support = support
        self.rest = {b.name: b.bone.head_local / M for b in self.bones}
        self.turn = {}
        self.joint = {}

    def orient(self, name, q, relative=False):
        bone = self.bones[name]
        parent = bone.parent.name if bone.parent else None
        parent_q = self.turn[parent] if parent else Quaternion()
        basis = bone.bone.matrix_local.to_quaternion()
        self.turn[name] = parent_q @ q if relative else q
        self.joint[name] = self.rest[name]
        if parent:
            self.joint[name] = self.at(parent, self.rest[name])
        bone.rotation_quaternion = basis.inverted() @ parent_q.inverted() @ self.turn[name] @ basis

    def at(self, bone, point):
        return self.joint[bone] + self.turn[bone] @ (Vector(point) - self.rest[bone])

    def limbs(self, start, middle, end, goal, pole, orientation):
        parent = self.bones[start].parent.name
        pivot = self.at(parent, self.rest[start])
        first = self.rest[middle] - self.rest[start]
        second = self.rest[end] - self.rest[middle]
        a, b = first.length, second.length
        axis = (goal - pivot).normalized()
        direction = Vector(pole)
        outward = (direction - axis * direction.dot(axis)).normalized()
        distance = min(a + b - .08, max(abs(a - b) + .08, (goal - pivot).length))
        along = (a*a - b*b + distance*distance) / (2*distance)
        bend = axis * along + outward * sqrt(max(0, a*a - along*along))
        reach = axis * distance - bend
        self.orient(start, first.rotation_difference(bend))
        self.orient(middle, second.rotation_difference(reach))
        self.orient(end, orientation)

    def arm(self, side, sign, offset, hand_pitch=0, hand_roll=0):
        upper = 'UpperArm.' + side
        wrist = self.at('Chest', self.rest[upper]) + Vector(offset)
        self.limbs(upper, 'Forearm.' + side, 'Hand.' + side, wrist,
                   (sign, .65, -.53), rotation(hand_pitch, sign*hand_roll))

    def contact_hand(self, side, sign, point, amount, offset, finger_direction, rest):
        upper, forearm, hand = ('UpperArm.' + side, 'Forearm.' + side, 'Hand.' + side)
        # Approach from outside the cheek. The fingertips, rather than the wrist,
        # meet the accessory. The elbow stays below the cheek throughout.
        fingers = Vector((sign*10, -4, -17))
        direction = self.turn['Head'] @ Vector(finger_direction)
        hand_q = fingers.rotation_difference(direction)
        shoulder = self.at('Chest', self.rest[upper])
        target_wrist = self.at('Head', point) - hand_q @ fingers
        wrist = (shoulder + Vector(offset)).lerp(target_wrist, amount)
        hand_q = rest.slerp(hand_q, amount)
        self.limbs(upper, forearm, hand, wrist, (sign, .25, -.62), hand_q)

    def body(self, hips, chest, head, glance=0, tilt=0, follow=0, flutter=0, counter=0):
        self.orient('Pelvis', rotation(hips, tilt*.19, -glance*.23))
        self.orient('Chest', rotation(chest, tilt*.38 + counter, glance*.36))
        self.orient('Head', rotation(head, tilt, glance))
        self.orient('Ornament', rotation(follow, -flutter*.3, follow*.26 + flutter), True)
        self.orient('Blink', Quaternion(), True)
        for side, sign in SIDES:
            self.orient('Lock.' + side, rotation(follow*.51, sign*flutter*.52), True)

    def feet(self, x, y, height, placements):
        """Each placement is (ankle x, ankle y, sole clearance, pitch, toe-out)."""
        positions = []
        for (side, sign), (ankle_x, ankle_y, lift, pitch, toe) in zip(SIDES, placements):
            thigh, shin, foot = ('Thigh.' + side, 'Shin.' + side, 'Foot.' + side)
            foot_q = rotation(pitch, 0, sign*toe)
            vertical = np.asarray(foot_q.to_matrix()[2])
            lowest = np.min((self.support[foot] - np.asarray(self.rest[foot])) @ vertical)
            ankle = Vector((ankle_x - x, ankle_y - y, lift - lowest))
            pivot = self.at('Pelvis', self.rest[thigh])
            reach = (self.rest[shin] - self.rest[thigh]).length + (self.rest[foot] - self.rest[shin]).length - .25
            horizontal = (ankle.x - pivot.x)**2 + (ankle.y - pivot.y)**2
            height = min(height, ankle.z - pivot.z + sqrt(max(1, reach**2 - horizontal)))
            positions.append((thigh, shin, foot, ankle, foot_q))
        for thigh, shin, foot, ankle, foot_q in positions:
            ankle.z -= height
            self.limbs(thigh, shin, foot, ankle, (0, -1, .12), foot_q)
        bone = self.bones['Pelvis']
        bone.location = bone.bone.matrix_local.to_quaternion().inverted() @ (Vector((x, y, height)) * M)


def poses(t, *keys):
    return sample(t, keys)


# Relaxed wrists hang beside the jacket. The two hands do not mirror each other
# during a gesture, even when the two arms rise together.
def relaxed(sign):
    return (sign*36, -5, -53)


def stride_feet(bib, t):
    result = []
    for _, sign in SIDES:
        phase = (t + (.5 if sign < 0 else 0)) % 1
        if phase < .28:
            q = phase / .28
            toe_off = max(0, (q - .72) / .28)**2
            y, lift, toe = -57 + 117*q, 8*toe_off, 20*toe_off
        else:
            q = (phase - .28) / .72
            y = 1.5 + 58.5*cos(pi*q) - (6 + bib%3)*sin(pi*q)**2
            lift = 8*(1-q) + (35, 45, 40, 39, 32, 37)[bib]*sin(pi*q)**1.35
            toe = 20*(1-q) - 17*sin(pi*q)
        result.append((sign*(34 + (1, 4, 0, 4, 2, 5)[bib]), y, lift, toe, 3 + bib%3*2))
    return result


def stride_body(bib, t, sprint=False):
    phase = 2*pi*t
    bob = sin(2*phase)
    swing = sin(phase)
    chest = (14, 9, 21, 17, 12, 12)[bib] + (9 if sprint else 0)
    head = (4, 1, 9, 6, 3, 0)[bib] - 3*bob + (4 if sprint else 0)
    orient = (6, 8, 4, 7, 3, 9)[bib]
    follow = (8, 7, 13, 5, 11, 9)[bib]*sin(2*phase - 1.07)
    return (6 if sprint else 2.5, chest + 2*bob, head, orient*swing,
            (3, 5, 2, 4, 2, 6)[bib]*cos(phase), follow, 5*swing)


def stride_arm(bib, t, sign, sprint=False):
    phase = 2*pi*t
    drive = sign*cos(phase - .08)
    width = (25, 36, 18, 27, 28, 31)[bib]
    sweep = (46, 41, 54, 48, 35, 45)[bib] + (8 if sprint else 0)
    return (Vector((sign*(width + 4*drive + 5*sin(phase)),
                    -13 + sweep*drive, -36 + 12*drive*drive + 12*max(0, -drive))),
            -24 - 29*drive)


def stride_upper(pose, bib, t, sprint=False):
    pose.body(*stride_body(bib, t, sprint))
    for side, sign in SIDES:
        wrist, pitch = stride_arm(bib, t, sign, sprint)
        pose.arm(side, sign, wrist, pitch, 6)


def stride(pose, bib, t):
    stride_upper(pose, bib, t)
    swing = 2*pi*t
    pose.feet(2.5*cos(swing), 0, -25 + 10*sin(2*swing), stride_feet(bib, t))


def idle(pose, bib, t):
    a = 2*pi*t
    sway = sin(a) * (1.0, 1.8, 1.0, 2.0, .8, 1.5)[bib]
    pose.body(0, 2 + cos(a), .9*cos(a + .6), sway*2, -sway, 1.7*sin(a - .4))
    for side, sign in SIDES:
        arm = relaxed(sign)
        pose.arm(side, sign, (arm[0], arm[1] + 1.2*sin(a + sign*.7), arm[2] + sway*sign))
    pose.feet(sway, 0, -5 + cos(a), [(sign*35, 0, 0, 0, 4) for _, sign in SIDES])


# Each row gives the preparation accent, rebound and when that racer comes out
# of it. The common final stance gives launch a single contact to start from.
PREP_BEATS = (
    (.26, .38, .60), (.43, .54, .70), (.23, .39, .64),
    (.35, .49, .71), (.47, .61, .72), (.29, .49, .72),
)
# x, y, root height, pelvis pitch, chest pitch, head pitch, look, head tilt, hair lag.
PREP_BODY = (
    (-6, 1, -9, -3, -5, -6, 8, 5, -5),
    (0, 0, 8, -4, -6, -8, -4, 3, 12),
    (8, 3, -10, 4, 13, 11, -27, 7, 8),
    (-3, -4, -5, 4, 9, 0, 10, -26, 0),
    (5, 2, -7, 2, 12, 14, 8, -6, 6),
    (-8, 2, -8, 1, 2, -4, 34, 8, -6),
)
PREP_WRISTS = (
    ((42, 36, -28), (-31, -37, -27)),
    ((55, -22, -14), (-62, -13, -19)),
    ((33, 25, -48), (-32, -23, -29)),
    ((33, 9, -48), (-49, -45, 15)),
    ((9, -43, -17), (-19, -42, -26)),
    ((41, 18, -39), (-53, -12, -38)),
)


def brace(bib):
    return (LEAD[bib]*3, 4, -24, 15, (28, 21, 34, 24, 19, 25)[bib], 6,
            -LEAD[bib]*7, 1, -4)


def ready(pose, bib, t):
    accent, rebound, clear = PREP_BEATS[bib]
    strength, = poses(t, (0, (0,)), (max(.04, accent-.22), (0,)),
                      (accent, (1,)), (rebound, (.96,)), (clear, (0,)))
    settling, = poses(t, (0, (0,)), (.70, (0,)), (.91, (1,)), (1, (1,)))
    base = (0, 0, -4, 0, 3, .74, 0, 0, -.67)
    setup = tuple(a + (b-a)*strength for a, b in zip(base, PREP_BODY[bib]))
    x, y, height, hips, chest, head, glance, tilt, follow = (
        a + (b-a)*settling for a, b in zip(setup, brace(bib))
    )
    pose.body(hips, chest, head, glance, tilt, follow, 3*strength - 3*settling,
              32*strength if bib == 3 else 0)
    lead = LEAD[bib]
    for index, (side, sign) in enumerate(SIDES):
        offset = Vector(relaxed(sign)).lerp(Vector(PREP_WRISTS[bib][index]), strength)
        forward = sign == lead
        offset = offset.lerp(Vector((sign*(28 if forward else 34),
                                     38 if forward else -37, -35 if forward else -28)), settling)
        pitch = -18*strength - (10 if forward else 40)*settling
        roll = 8*strength
        if bib == 3 and sign < 0:
            touch, = poses(t, (0, (0,)), (.24, (0,)), (.35, (1,)),
                           (.49, (.99,)), (.58, (0,)), (1, (0,)))
            pose.contact_hand(side, sign, (-84, -21, 278), touch, offset,
                              (-.70, -.20, .60), rotation(pitch, sign*roll))
        else:
            pose.arm(side, sign, offset, pitch, roll)
    placements = []
    for _, sign in SIDES:
        forward = sign == lead
        step = poses(t, (0, (0,)), (.674 if forward else .79, (0,)),
                     (.79 if forward else .925, (1,)), (1, (1,)))[0]
        hop = 11*strength if bib == 1 else 0
        placements.append((sign*(35 + 4*step), (-22 if forward else 33)*step,
                           hop + 9*sin(pi*step), 0 if forward else 8*step, 4 + 3*step))
    pose.feet(x, y, height, placements)


def launch(pose, bib, t):
    lead = LEAD[bib]
    end_phase = .345
    push, merge = poses(t, (0, (0, 0)), (.35, (1, 0)), (.55, (.8, .16)), (1, (0, 1)))
    x, y, h, hips, chest, head, glance, tilt, follow = brace(bib)
    a = 2*pi*end_phase
    push_body = (hips, chest + 15*push, head + 10*push, glance - 5*push,
                 tilt, follow + 14*push, -3 + 8*push)
    pose.body(*(start*(1-merge) + end*merge
                for start, end in zip(push_body, stride_body(bib, end_phase))))
    # Ground anchors move backwards by the distance the simulation advances.
    # The chest crosses the leading shoe before the rear leg swings through.
    travel = 143*t*t
    run = stride_feet(bib, end_phase)
    placements = []
    for index, (side, sign) in enumerate(SIDES):
        front = sign == lead
        start_wrist = Vector((sign*(28 if front else 34), 38 if front else -37, -35 if front else -28))
        run_wrist, run_pitch = stride_arm(bib, end_phase, sign)
        wrist = start_wrist.lerp(run_wrist, merge)
        wrist.y += (-40 if front else 39)*push
        start_pitch = -10 if front else -40
        pose.arm(side, sign, wrist, start_pitch*(1-merge) + run_pitch*merge, 6*merge)
        start_y = -22 if front else 33
        lift = poses(t, (0, (0,)), (.30, (0 if front else 9,)),
                     (.57, (9 if front else 39,)), (1, (0,)))[0]
        foot_x, foot_y, foot_lift, foot_pitch, toe = run[index]
        placements.append((sign*39*(1-merge) + foot_x*merge,
                           (start_y + travel - (74*t*t if not front else 0))*(1-merge) + foot_y*merge,
                           lift*(1-merge) + foot_lift*merge,
                           ((0 if front else 8) + 17*push)*(1-merge) + foot_pitch*merge,
                           7*(1-merge) + toe*merge))
    pose.feet(x*(1-merge) + 2.5*cos(a)*merge, y*(1-merge) - 9*push,
              h + 15*push + (-25 + 10*sin(2*a) - h)*merge, placements)


def jump(pose, bib, t):
    lead = LEAD[bib]
    lift, hips, chest, head, tilt, hair = poses(
        t, (0, (-16, 17, 27, 6, -2, -9)), (.13, (-8, 8, 13, 0, 2, 11)),
        (.40, (-1, 2, 6, -7, 9, 19)), (.58, (-3, 4, 10, -3, 6, 5)),
        (.78, (-10, 8, 15, 1, -1, -12)), (1, (-17, 11, 21, 6, -5, -10)),
    )
    pose.body(hips, chest, head, lead*6*sin(2*pi*t), tilt*lead, hair, lead*hair*.35*sin(pi*t))
    feet = []
    for side, sign in SIDES:
        front = sign == lead
        y, z, pitch = poses(
            t,
            (0, (-25, 0, 13) if front else (40, 10, 29)),
            (.16, (-58, 31, -12) if front else (39, 31, 57)),
            (.46, (-60, 60 + (5 if bib == 2 else 0), -27) if front else (23, 28, 57)),
            (.64, (-55, 53, -13) if front else (37, 18, 46)),
            (.83, (-43, 13, -5) if front else (44, 22, 35)),
            (1, (-34, 0, 0) if front else (30, 18, 31)),
        )
        feet.append((sign*(35 + 4*sin(pi*t)), y, z, pitch, 4))
        sideward = (13, 25, 7, 19, 13, 22)[bib] if front else (21, 30, 8, 19, 16, 22)[bib]
        wrist = poses(
            t, (0, (sign*34, 39 if front else 28, -31)),
            (.23, (sign*(40 + sideward*.65), -23 if front else -36, -13)),
            (.48, (sign*(41 + sideward) if front else sign*(31 + sideward), 22 if front else -41, -22 if front else 13)),
            (.74, (sign*(22 + sideward), -26 if front else -42, -19)),
            (1, (sign*(24 + sideward*.45), -44, -22)),
        )
        pose.arm(side, sign, wrist, -28 - 20*sin(pi*t), 15*sin(pi*t))
    pose.feet(lead*3*sin(pi*t), 0, lift, feet)


def land(pose, bib, t):
    lead = LEAD[bib]
    compress, settle = poses(t, (0, (0, 0)), (.29, (1, 0)), (.53, (.83, .19)), (1, (0, 1)))
    pose.body(11 + 8*compress - 8*settle, 21 + 17*compress - 7*settle,
              6 + 14*compress - 5*settle, -lead*4*settle, -lead*(5 + compress*3),
              -10 + 28*compress + 5*settle, lead*4*compress)
    feet = []
    for side, sign in SIDES:
        front = sign == lead
        if front:
            # Follow the forward travel of the pelvis until the second foot
            # takes weight. The leading sole stays down during compression.
            release, = poses(t, (0, (0,)), (.64, (0,)), (1, (1,)))
            y = -34 + 125*t - 36*release
            lift, pitch = 14*release, 16*release
        else:
            y, lift, pitch = poses(t, (0, (30, 18, 31)), (.29, (9, 29, 25)),
                                   (.64, (-38, 0, 0)))
            y += 125*max(0, t-.64)
        feet.append((sign*35, y, lift, pitch, 4))
        spread = (9, 32, 8, 15, 8, 19)[bib]
        pose.arm(side, sign, (sign*(24 + (13, 25, 7, 19, 13, 22)[bib]*.45 + spread*compress),
                             -44 + (33 if front else 3)*settle, -22 + 13*compress - 7*settle),
                 -28 + 17*settle, 17*compress)
    pose.feet(lead*3*compress, -9*compress, -17 - 15*compress + 6*settle, feet)


def lost_balance(pose, bib, t, airborne):
    lead = LEAD[bib]
    if airborne:
        height, hips, chest, head, swing, tilt, hair = poses(
            t, (0, (-15, 9, 20, 6, 0, 0, 0)), (.27, (-8, -10, -18, 17, 15, -20, -14)),
            (.61, (-22, 23, 47, 30, -22, 24, 37)), (1, (-12, 46, 57, 36, -16, 17, 28)))
    else:
        height, hips, chest, head, swing, tilt, hair = poses(
            t, (0, (-20, 6, 15, 6, 0, 0, 0)), (.17, (-29, 23, 45, 22, 13, -15, 25)),
            (.37, (-29, 5, -7, 8, -21, 18, -11)), (.58, (-21, 9, 22, 4, 8, -8, 4)),
            (.78, (-27, 14, 30, 7, -6, 5, 7)), (1, (-23, 4, 16, 3, 0, 0, -2)))
    pose.body(hips, chest, head, lead*swing, lead*tilt, hair, swing*.7)
    feet = []
    for side, sign in SIDES:
        off_phase = min(1, max(0, t*1.37 - (.36 if sign == lead else 0)))
        flare = sin(pi*t)**.7
        reaches = sign == lead
        wrist = (sign*(31 + (18 if reaches else 32)*flare),
                 -18 + (-41 if reaches else 26)*flare,
                 -43 + (63 if reaches else 41)*flare)
        pose.arm(side, sign, wrist, -35 - (42 if reaches else 11)*flare, 17*flare)
        step = sin(pi*off_phase)
        y = -36 + 76*off_phase if sign == lead else 28 - 76*off_phase
        feet.append((sign*(36 + 8*step), y, (34 if airborne else 20)*step, 45*step if airborne else 14*step, 6))
    pose.feet(swing*lead*.42, -9*sin(pi*t), height, feet)


# Normal places show fatigue followed by a personal reaction. These offsets
# are relative to each shoulder, while both ankles stay on their marks.
FINISH_BODY = (
    (-5, 8, -14, 5, 19, -3, 13, -6, -3),
    (8, 2, -8, 2, 4, -6, -16, 8, 5),
    (2, 9, -17, 8, 27, 14, -5, 5, 7),
    (8, 5, -9, -3, 7, -6, -14, -14, -3),
    (6, 4, -10, 7, 16, 15, -9, 15, 2),
    (-6, 4, -9, 4, 3, -3, -27, 7, -3),
)
FINISH_WRISTS = (
    ((17, -26, -38), (-16, -24, -39)),
    ((56, -33, -3), (-59, -19, -21)),
    ((19, -35, -54), (-29, 6, -45)),
    ((16, 12, -32), (-35, -8, -48)),
    ((32, -43, -15), (-29, -15, -47)),
    ((32, -10, -51), (-60, -24, 28)),
)
WIN_BODY = (
    (-6, 2, -3, -4, -6, -8, 6, -7, -6),
    (3, -2, -2, -3, -8, -8, -9, -4, 5),
    (-7, 2, -7, -2, -4, -3, 18, 9, 7),
    (9, 1, -6, -2, -7, -5, -11, -11, -7),
    (4, 6, -7, 0, 4, -4, -8, 7, 3),
    (-8, 3, -5, -3, -6, -4, -16, 11, 6),
)
WIN_WRISTS = (
    ((58, -31, 41), (-17, -20, -30)),
    ((61, -23, 46), (-61, -26, 42)),
    ((21, -30, -36), (-56, -42, 31)),
    ((61, -38, 39), (-39, -24, -32)),
    ((44, -48, 20), (-47, -36, -18)),
    ((59, -24, -8), (-62, -25, 26)),
)
FINISH_BEAT = (.38, .43, .36, .46, .52, .46)


def finish(pose, bib, t, winning):
    accent = FINISH_BEAT[bib]
    lift, hit, tail = poses(t, (0, (0, 0, 0)), (.14, (1, 0, 0)), (.23, (.87, 0, 0)),
                            (accent, (0, 1, 0)), (accent+.10, (0, .98, .2)),
                            (.78, (0, .76, 1)), (1, (0, .64, 1)))
    base = (0, 2, -7, 3, 8, 2, 0, 0, 0)
    performer = WIN_BODY[bib] if winning else FINISH_BODY[bib]
    x, y, h, hips, chest, head, glance, tilt, hair = (
        a + (b-a)*hit for a, b in zip(base, performer)
    )
    # A sharp punctuation is followed by slower hair settling and a held face.
    wobble = sin(tail*2*pi)
    pose.body(hips + 6*lift, chest + 25*lift, head + 17*lift, glance, tilt,
              hair - 5*lift + 6*wobble, 5*wobble)
    for index, (side, sign) in enumerate(SIDES):
        start = Vector(relaxed(sign)).lerp(Vector((sign*23, -29, -51)), lift)
        gesture = Vector((WIN_WRISTS if winning else FINISH_WRISTS)[bib][index])
        offset = start.lerp(gesture, hit)
        if bib == 5 and sign < 0:
            wave = sin(2*pi*(t-accent)*7) * sin(pi*max(0, min(1, (t-accent+.08)/.50)))
            offset.x += 8*wave
            offset.z += 5*wave
        raised = min(1, max(0, (offset.z + 10)/25))
        pitch, roll = -12 - hit*(35 + 80*raised), (7 + 12*raised)*hit
        if bib == 4 and sign > 0 and not winning:
            touch, = poses(t, (0, (0,)), (.29, (0,)), (.47, (1,)), (.57, (1,)), (.79, (0,)), (1, (0,)))
            pose.contact_hand(side, sign, (65, -38, 238), touch, offset,
                              (.47, -.33, .82), rotation(pitch, sign*roll))
        else:
            pose.arm(side, sign, offset, pitch, roll)
    pose.feet(x, y, h - 13*lift, [(sign*37, -10 if sign == LEAD[bib] else 10, 0, 0, 8)
                                 for _, sign in SIDES])


def performance_pose(rig, bib, state, t, support):
    if state in ('dive', 'slide'):
        sport_pose(rig, bib, state, t, support)
        return
    pose = Pose(rig, support)
    if state == 'idle':
        idle(pose, bib, t)
    elif state == 'ready':
        ready(pose, bib, t)
    elif state == 'launch':
        launch(pose, bib, t)
    elif state == 'run':
        stride(pose, bib, t)
    elif state == 'sprint':
        # The calibrated sprint still owns shoe contact and its low pelvis.
        sport_pose(rig, bib, state, t, support)
        pelvis = rig.pose.bones['Pelvis']
        body_rotation = pelvis.rotation_quaternion.copy()
        stride_upper(pose, bib, t, sprint=True)
        pelvis.rotation_quaternion = body_rotation
    elif state == 'jump':
        jump(pose, bib, t)
    elif state == 'land':
        land(pose, bib, t)
    elif state in ('stumble', 'fall'):
        lost_balance(pose, bib, t, state == 'fall')
    elif state in ('finish', 'finish_win'):
        finish(pose, bib, t, state == 'finish_win')
    else:
        raise ValueError(state)
