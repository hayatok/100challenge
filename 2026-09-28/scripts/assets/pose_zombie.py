"""Bend the arms of the authored Zombie_Walk clip toward the camera.

Run after convert_rikindle.py. Only animation quaternion samples change; geometry,
textures, skeleton bind pose, and the other clips stay as authored. The marker
prevents accidentally applying the pose twice.
"""

import json
import math
import os
import struct

app = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
path = os.path.join(app, "public/assets/characters/zombie.glb")
corrections = {
    "mixamorig:LeftArm": (-0.44, 0.50, 1.00),
    "mixamorig:LeftForeArm": (-0.75, 1.00, 0.50),
    "mixamorig:RightArm": (0.13, -0.69, -1.31),
    "mixamorig:RightForeArm": (-0.39, 0.49, -0.24),
}


def euler_xyz(euler):
    x, y, z = (value / 2 for value in euler)
    c1, c2, c3 = math.cos(x), math.cos(y), math.cos(z)
    s1, s2, s3 = math.sin(x), math.sin(y), math.sin(z)
    return (
        s1 * c2 * c3 + c1 * s2 * s3,
        c1 * s2 * c3 - s1 * c2 * s3,
        c1 * c2 * s3 + s1 * s2 * c3,
        c1 * c2 * c3 - s1 * s2 * s3,
    )


def multiply(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return (
        x1 * w2 + w1 * x2 + y1 * z2 - z1 * y2,
        y1 * w2 + w1 * y2 + z1 * x2 - x1 * z2,
        z1 * w2 + w1 * z2 + x1 * y2 - y1 * x2,
        w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
    )


with open(path, "rb") as file:
    header = file.read(12)
    assert header[:4] == b"glTF" and struct.unpack_from("<I", header, 4)[0] == 2
    json_size, json_type = struct.unpack("<I4s", file.read(8))
    assert json_type == b"JSON"
    data = json.loads(file.read(json_size))
    bin_size, bin_type = struct.unpack("<I4s", file.read(8))
    assert bin_type == b"BIN\0"
    binary = bytearray(file.read(bin_size))

clip = next(animation for animation in data["animations"] if animation["name"] == "Zombie_Walk")
if clip.get("extras", {}).get("nightshift_arm_pose"):
    raise SystemExit("Zombie_Walk arm pose is already applied")

done = set()
for channel in clip["channels"]:
    target = channel["target"]
    bone = data["nodes"][target["node"]]["name"]
    if target["path"] != "rotation" or bone not in corrections:
        continue
    accessor = data["accessors"][clip["samplers"][channel["sampler"]]["output"]]
    assert accessor["componentType"] == 5126 and accessor["type"] == "VEC4"
    view = data["bufferViews"][accessor["bufferView"]]
    assert view.get("byteStride", 16) == 16
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    correction = euler_xyz(corrections[bone])
    for sample in range(accessor["count"]):
        offset = start + sample * 16
        original = struct.unpack_from("<4f", binary, offset)
        result = multiply(original, correction)
        norm = math.sqrt(sum(component * component for component in result))
        struct.pack_into("<4f", binary, offset, *(component / norm for component in result))
    done.add(bone)
assert done == set(corrections), done

clip.setdefault("extras", {})["nightshift_arm_pose"] = "1"
json_bytes = json.dumps(data, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
json_bytes += b" " * (-len(json_bytes) % 4)
assert len(binary) % 4 == 0
length = 12 + 8 + len(json_bytes) + 8 + len(binary)
with open(path, "wb") as file:
    file.write(struct.pack("<4sII", b"glTF", 2, length))
    file.write(struct.pack("<I4s", len(json_bytes), b"JSON"))
    file.write(json_bytes)
    file.write(struct.pack("<I4s", len(binary), b"BIN\0"))
    file.write(binary)
print("Updated", path, length, sorted(done))
