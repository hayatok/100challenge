# Evacuation character meshes

Run `blender -b -P bake.py -P motion.py` with Blender 5.3 from this
directory. The character meshes and animation table are written directly to
the game's World resources. Each of the eleven characters has a close
`actor{kind}_{variant}` mesh and a distant `actorFar{kind}_{variant}` mesh
with the same scale, material IDs and movement pivots.

The source mesh supplies the head, hands, eyelids and face geometry. Blender
reduces the anatomy for each level of detail. The exporter builds new
clothing, boots and equipment. The far export keeps the main garment
silhouette and equipment profile with fewer sections, smaller head and hand
meshes and fewer seams and fittings.

`hm08.obj.gz` contains an unmodified OBJ compressed with gzip. The source is
[MakeHuman hm08](https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data/3dobjs/base.obj).
Data Collection AB, Joel Palmius and Jonas Hauquier released this mesh under
CC0 in September 2020. The original notice is in the OBJ header and the
[license text](LICENSE.ASSETS.md) accompanies it.

`Game/Assets/Resources/World/FieldFaces.png` is the project's six-portrait
Moss-image output `field-faces_00001_.png`. Skeletal part IDs occupy the low
nibble of the mesh attribute. Face triangles use surface ID 12 and normalized
atlas coordinates. The exported normals use the same axes as the positions.

`motion.py` solves thigh and knee angles against hand-keyed foot positions
for contact, weight acceptance, push-off and swing in three gait cycles.
The shader interpolates the keys and blends cycles with speed. Pants and
sleeves use continuous vertex strips and blend the bend through the fabric
at the knee and elbow. Shoes rotate independently from the shin. The
trigger hand and carried tool share shoulder and elbow rotations. The
support, repair, cargo and fall poses add separate arm and torso movement.

The first-person poses use a second MakeHuman hand cut with more geometry.
Run `blender -b -P ../streets.py -- --viewmodels-only` to regenerate the
three viewmodel meshes.
`viewmodel.py` wraps the fingers around each hand's grip. The runtime moves
the support arm and detached equipment through the reload, and uses the
same object and wrist motion when the player carries cargo.

The gait bake also exports `ActorGait.Keys.cs` from the same sampled curves.
Near characters hold the active ankle in world space during stance. Their
CPU leg solve shares the shader's rest pivots, and the shoe keeps its authored
heel-to-toe pitch. The crowd's distant meshes continue to sample gait
without contact tracking. Companion poses use the paired shoulder position
when available. A patient on the stretcher uses the same civilian mesh,
rotated onto the mattress with a separate resting pose.
