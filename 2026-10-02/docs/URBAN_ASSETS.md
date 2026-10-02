# Urban character, weapon and material assets

The urban slice uses licensed third-party human character/weapon art and two licensed surface textures. Its street geometry, game design, encounter layout, animation corrections, recolors, firearm fitting and supplemental sleeve/cuff geometry are authored for this project. No commercial franchise assets or paid downloads are used. The existing `2026-09-28` app is unchanged; its already-licensed converted models are input assets only.

## Ready-to-use runtime contract

### Human city zombie

- `game/assets/models/city/zombie_city.glb`: skinned human, 66 bones, three material surfaces, 12 animation clips
- Godot coordinate system: Y up, model front +Z; rest height 1.795 m, feet Y≈0. Use scale 1.0 and place the actor root on pavement
- Primary animations: `Zombie_Walk` (4.0 s), `Zombie_Idle` (4.3667 s), `Zombie_Attack` (4.6667 s), `Zombie_Reaction_Hit` (4.0667 s), `City_Death` (1.55 s)
- Other source clips retained: `Walking`, `Zombie_Idle2`, `Zombie_Attack2`, `Zombie_Attack3`, `Zombie_Dying`, `Zombie_Running`, `Zombie_Scream`. Do not use `Zombie_Dying` as a death: it is authored in the get-up direction
- `City_Death` reverses and retimes that source to a 1.55-second weighted collapse, clamps the falling pelvis to 0.20 m, and settles both upper/lower arms to the pavement. Do not loop the death; allow the AnimationPlayer to hold its terminal pose
- Actual Godot terminal positions at scale 1: pelvis Y=0.2000, head Y=0.2430, left/right hands Y=0.0577/0.0639, elbows Y=0.1033/0.0702 m. The authored fall also translates the torso sideways; reserve about 1.5 m of ground around a corpse
- Source rig names are `mixamorig:Hips`, `mixamorig:Head`, `mixamorig:LeftArm`, `mixamorig:LeftForeArm`, `mixamorig:LeftHand` and right-side equivalents. Godot normalizes colons to underscores: `mixamorig_Hips`, `mixamorig_Head`, `mixamorig_LeftHand`, etc
- Both idle clips have bent/lowered arms, correcting the source T-pose arm hold. Walking preserves the licensed source conversion's corrected arm gesture
- Original skin/cloth sculpted geometry and UVs remain intact. New 1024² baked albedo distinguishes pale muted skin, a worn blue-gray shirt and dark trousers while retaining scars, tears and seams. Skin/cloth are nonmetallic; roughness 0.82/0.90 and normal strengths 0.11/0.16 reduce the original stone-like specular sculpting

### Runner variation

- `game/assets/models/city/thin_zombie.glb`: 41-bone skin, original licensed 1024² texture, eight clips
- Height 1.799 m, source feet Y≈0.032 m. A 0.032 m downward offset brings its feet to the actor root
- Clips: `walk` (1.25 s), `walk2` (1.7083 s), `run` (1.6667 s), `idle` (1.6667 s), `attack1_l`/`attack1_r` (1.6667 s), `hurt` (1.6667 s), `dead1` (1.625 s)
- Suggested runner contract: loop `run`, attack `attack1_l`, single-shot death `dead1`
- Godot bones retain names such as `hips`, `head`, `upper_arm.L`, `forearm.L`, `hand.L` and right-side equivalents
- This is CC BY 3.0, with mandatory Rosswet Mobile attribution; see notices

### Coherent first-person pistol and hands

- `game/assets/models/city/pistol_hands.glb`: attach the imported scene directly below Camera3D with identity position, rotation and scale. No extra 90-degree turn is needed
- Camera-local forward is −Z. The two genuine anatomical textured hand/forearm islands are posed and baked into a supported pistol grip, with original olive cloth material and rounded cuffs. Arms are static grip meshes, not a new independently authored human rig; apply recoil/sway to the scene parent
- Runtime children include `Grip_Hands_Anatomical`, `Pistol_Barrel`, `Pistol_Slide`, `Pistol_Frame`, `Pistol_Trigger`, `Pistol_Hammer`, `Sleeve_Cuff_L`, `Sleeve_Cuff_R`, `Muzzle`. The author's loose spare magazine is removed
- `Muzzle` is verified in Godot at camera-local `(0.100000, 0.0076473, -0.7182847)`. Read that node's global position for light/flash integration, because parent recoil changes it
- Source barrel was +X. The conversion includes its +90° yaw, blued-steel albedo bake, reduced normal strength 0.32, steel roughness 0.40/metallic 0.72, polymer roughness 0.76/metallic 0.15
- Recoil, slide movement, muzzle flash and impact response belong to gameplay code. This GLB has no animation player
- Preview is a true 1280×720 Blender geometry render with camera at origin, roughly 70° horizontal FOV, not a generated concept image: `art/source/city/pistol_hands_fit_preview.png`

### Environment surfaces

`game/assets/materials/worn_asphalt/` and `worn_shutter/` each contain unmodified 1024² `diffuse.jpg`, `normal.jpg`, `roughness.jpg` from Poly Haven. Normals are OpenGL convention. The geometry, UV repeat, roughness response and lighting are original world-code choices; texture source bytes are unchanged.

## Provenance and licenses

`art/source/city/provenance.json` records current official-page evidence, exact stable source/license URLs, downloaded archive hashes and final runtime-file hashes. Licensing was independently rechecked on 2026-10-02; it does not depend only on the older app's notices.

- City zombie: Rikindle3D, [official source](https://opengameart.org/content/male-city-zombie-ready-for-use-in-game-engines), [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). The author page explicitly selects CC0. Current source archive hash matches the original licensed conversion input; no separate embedded text license is in the archive
- Pistol: loafbrr_1, [official source](https://opengameart.org/content/pistol-5), CC0. The current author archive README explicitly says Creative Commons 0; the page also documents correction of an older mistaken license wording. Exact first-line evidence: `art/source/city/licenses/PISTOL-ARCHIVE-LICENSE.txt`
- FPS arms: para, [official source](https://opengameart.org/content/fps-arms-rigged-only), CC0. The author credits MakeHuman for base mesh/texture; [official MakeHuman core-asset license](https://static.makehumancommunity.org/about/license.html) was also checked. Current archive hash matches the licensed input; no separate textual license is embedded
- Thin Zombie: Rosswet Mobile, submitted by dogchicken, [official source](https://opengameart.org/content/thin-zombie-awake-zombie-asset), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/). The page's attribution instructions explicitly name Rosswet Mobile. The notice preserves title, author, source, license and modifications
- Worn Asphalt: Amal Kumar; Worn Shutter: Dimitrios Savva; [Poly Haven license](https://polyhaven.com/license). The official license explicitly permits CC0 use and redistribution, including source textures
- Gunshot Sounds: copyright 2009 Vincent Sevedge. The OGA page selects CC0 but the current downloaded author's `sounds/creativecommons.txt` explicitly states CC BY 3.0; the stricter archive license is used. Exact original notice is preserved in `art/source/city/licenses/GUNSHOT-ARCHIVE-LICENSE.txt`
- Impact Sounds: Kenney, [official source](https://kenney.nl/assets/impact-sounds), CC0. The official page reconfirmed that license

CC0 permits asset redistribution and modification. CC BY 3.0 permits copying and adaptations subject to attribution, a license link and change disclosure. Neither license implies author endorsement. Raw author ZIP/7z/FBX archives are outside the app and are not included in runtime exports. Redundant baseline runtime GLBs and their generated texture duplicates were backed up outside the project before removal. Required imported texture files for the three live GLBs remain.

## Reproduction and verification

1. `python3 art/source/city/prepare_city_assets.py` uses the older repository's licensed GLB inputs to bake recolors and append corrected death/idle tracks. It requires Python, NumPy, Pillow and SciPy
2. `/usr/bin/blender --background --factory-startup --python art/source/city/build_pistol_hands.py` imports the credited arm/pistol GLBs, poses and bakes the grip, exports the coherent scene and renders its verification image. It does not use or modify an open Blender scene
3. `/usr/bin/blender --background --factory-startup --python art/source/city/validate_city_render.py` independently reloads the new city GLB and renders its actual facial/cloth geometry. Numeric report: `art/source/city/blender_validation.json`
4. After Godot import, run `/workspace/shared/godot/bin/godot --headless --path game --script ../art/source/city/validate_godot_assets.gd`. This checks actual imported clips, skeleton names, terminal death bone positions and camera-local muzzle. Report: `art/source/city/godot_asset_contract.json`

Blender 4.3.2 and Godot 4.7.2 were used. Godot verification completed without errors after the validation scene was deferred into the live tree. Native encounter screenshots/video are owned by overall game QA; a Blender render alone does not establish gameplay quality. The asset pass also reviewed `builds/urban-normal/black_relay_capture.png` after integration: connected hands/cuffs and a dark pistol were visible at the grip, the zombie face and dark trousers were readable, and corpse hands rested on the street rather than being held aloft. The earlier near fixture predates the final camera-relative weapon framing. These are detailed game assets with inherited mesh/texture limits, not a claim of film/AAA production quality.
