# Suits for the Kinsei cast

Margaret Toigo created the source geometry, UVs, diffuse maps and tangent-space normal maps. MakeHuman Community lists both `toigo_male_suit_3` and `toigo_male_double-breasted_suit` under CC0. The source ZIP also includes the corresponding asset headers and material definitions. [MakeHuman pack and individual license entries](https://static.makehumancommunity.org/assets/assetpacks/suits01.html) · [Download Suits 01](https://files.makehumancommunity.org/asset_packs/suits01/suits01_cc0.zip) · [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)

The source archive SHA-256 is `2b1d8676f3863b188e9eea98c1d8f234543d54c440e791d92b819f8ee1861f19`. Run `python bake.py path/to/suits01_cc0.zip` with NumPy and Pillow to regenerate the two fitted meshes and five colorways. The bake rotates the original A-pose sleeves and brings the trouser legs into the actor's narrower stance. The original UV layout is preserved. The Unity binding attaches the garments to ten existing pelvis, spine, arm and leg joints.

`fitting.png` is the offline Blender 5.3 Cycles fitting render of the exported meshes, color and normal maps. The preview command is `blender -b -P preview.py -- /absolute/path/to/fitting.png`. It shows the static garments before hands, faces, shoes, character animation and game lighting are applied.
