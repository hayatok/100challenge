# Evacuation character meshes

Run `blender -b -P bake.py` with Blender 5.3. The script writes the eleven
actor meshes directly to the game's World resources. It cuts the head and
hands from the source mesh, reduces them in Blender, projects the face chart,
and builds the garments, gear and hair around the existing animation pivots.

`hm08.obj.gz` contains an unmodified OBJ compressed with gzip. The source is
[MakeHuman hm08](https://github.com/makehumancommunity/makehuman/blob/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data/3dobjs/base.obj).
Data Collection AB, Joel Palmius and Jonas Hauquier released this mesh under
CC0 in September 2020. The original notice is in the OBJ header and the
[license text](LICENSE.ASSETS.md) accompanies it.

`Game/Assets/Resources/World/FieldFaces.png` is the project's six-portrait
Moss-image output `field-faces_00001_.png`. Skeletal part IDs occupy the low
nibble of the mesh attribute. Face triangles use surface ID 12 and normalized
atlas coordinates. The exported normals use the same axes as the positions.

Run `blender -b -P motion.py` to regenerate `ActorMotion.cginc`. The movement
starts with original, hand-keyed foot positions and angles for contact, weight
acceptance, toe-off and swing. Blender solves thigh and knee angles against
each ankle, keys each side and the weight transfer on separate pose bones, and
exports the resulting twelve-frame walk, run and protective limp cycles.
The shader interpolates the keys and blends cycles with speed. Shoe IDs 11
and 12 let the heel and toe roll independently from the shin.
