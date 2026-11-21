# Kinsei cast

`KinseiActor` uses meter-scale geometry with feet at the root and +Z forward. Main cast height is about 1.7 m. The caller moves and turns the root. The procedural jacket sleeves and trousers use continuous deforming meshes at the elbows and knees. Jacket collars cover the cropped neck, and back seams and wool textures are visible from the shoulder camera.

- `Init(role, variant)` creates a cast member. Roles are makabe, tatsu, kaji, brother, boss, ally and guard.
- `Pose(state, speed, action)` applies the current pose. Walk and run follow horizontal travel and aim for flat-ground foot contacts. Sit and talk distinguish Tatsu's ashtray beat and Kaji's response. A low combat guard, aim, shot, flinch, and fall are separate poses.
- `SetConversationTargets(otherEyes, ashtray)` sets world-space targets for the seated partner's gaze and Tatsu's right palm. The scene owns chair and ashtray placement.
- `SetAttentionTarget(worldEyes)` sets the world-space target for combat guard and aim gaze.
- `SetMirrorTarget(worldContact)` sets the midpoint between both palm contacts. The arm solver clamps each target to within reach. The `mirror` and `brother-call` poses use normalized relay progress. The brother looks aside, touches his collar, then looks toward the relay and mouths a line.

The heads use MakeHuman's Asian male macro targets. Makabe uses the adult face, Tatsu and the brother use young faces with different hairstyles, and Kaji and the boss use elder faces. Tatsu wears red-brown double-breasted tailoring, the boss wears cream and the brother wears olive-grey. The fitted hair profiles have distinct fringe, temple and nape shapes. The anatomical hands curl when relaxed or ready, close around the solid screen prop while aiming, and open for the mirror.

## Sources and licenses

- MakeHuman core base mesh, Asian male young/old and universal male young morphs, official repository commit `a8bc2d54ff0ac92e78ff71431b1023eda42bf482`: https://github.com/makehumancommunity/makehuman/tree/a8bc2d54ff0ac92e78ff71431b1023eda42bf482/makehuman/data . These core graphical assets are CC0, distinct from MakeHuman program source (AGPL). Verified: https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md and https://www.makehumancommunity.org/about/license.html . Full asset license preserved in Source/CC0.txt.
- Aksel Skin, author Mindfront, CC0, diffuse/normal/specular: https://www.makehumancommunity.org/node/850 .
- Old Eurasian Male, author OnlyTheGhosts, CC0, diffuse: https://www.makehumancommunity.org/node/1581 .
- Both skins obtained from official CC0 skins02 pack: https://files.makehumancommunity.org/asset_packs/skins02/skins02_cc0.zip . Original per-asset author/license records preserved in Source/skin-license-metadata.json. Pack documentation: https://static.makehumancommunity.org/assets/assetpacks/skins02.html .

Only head/neck and hand geometry is included, and texture atlases are masked to those UV islands. Tailoring, hair, eye details and animation code are original project work. No executable asset package was downloaded. Local Blender 5.3 processed data offline.

## Reproduction and validation

Source/human_parts.json contains the UV-preserving meshes before subdivision. Run `blender -b --python build_human_parts.py -- <human_parts.json> <Resources/KinseiCast> <Aksel_Skin_diffuse.png>` to rebuild the head and hand OBJs and an offline head image. Run `python prepare_skin_maps.py <human_parts.json> <extracted skins02/skins> <Resources/KinseiCast>` with Pillow to rebuild the masked skin maps.

Run `python build_tailoring.py` with NumPy and Pillow after rebuilding the head OBJs. It fits four hair meshes to the canonical adult, young and elder heads and writes directional hair color maps plus wool color and normal maps. The Python packages are offline authoring dependencies. `Editor/KinseiSkinImporter.cs` configures OBJ readability and texture import. At runtime, the skin loader checks the signed head depth and hand fingertip position to correct asset reflection while preserving UVs, normal direction and face winding.

Blender checked the scalp and hair fit from the front and rear. Current gameplay captures verify the integrated pose and lighting separately. The gait solver assumes a flat local floor, seated mouth motion follows pose timing, and hair uses sculpted surfaces with directional texture.
