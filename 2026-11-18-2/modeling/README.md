# Combat asset source

Run from the app directory:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python modeling/01_build_assets.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://combat/test_combat.gd
/Applications/Godot.app/Contents/MacOS/Godot --path game --script res://combat/test_visual.gd
```

The build produces seven GLBs, embedded original 32x32 nearest-filter wear textures and cropped face/fabric atlas panels from the supplied cast sheet, `combat_assets.blend`, a manifest, and `review/lineup.png`. Source constants use metres. Character-facing direction is Godot -Z. A wrapper preserves this orientation while runtime code rotates the body and separate head/arm/leg/knee pivots.

References: `art/market.png`, `art/cast.png`, `art/weapons.png`. The supplied face, navy cloth, orange raincoat, and apron atlas panels are cropped in the Blender build and mapped to the meshes. Worker cap/teal apron, runner orange hood, brass helmet diver, and captain hat/chain/shoulder wound are represented. Hidden rear surfaces, weapon mechanisms, and exact dimensions are inferred. These deliberately simplified rigid low-poly assets do not reproduce the concept's organic surface detail; no numerical silhouette-equivalence claim is made.

Runtime animations include asymmetric walk/run, arm attack, flinch, heavy windup/charge, falling death, recoil, belt motion and belt-swap tilt. They are procedural Godot joint transforms, not embedded skeletal animation clips. Cast receive hits through capsule collision bodies; ordinary enemy head hits receive a 1.7x multiplier. The captain has 720 HP and 0.3x armoured body damage; an exposed shoulder or back takes 4x damage. Its warning, charge, sweep, recovery, and half-health double-charge states create the damage opportunity. Fallen enemies immediately lose their damage/hit collision and sink below the floor after five seconds.

`test_combat.gd` checks model imports and all four pivot sets, state save/restore, boss warning/charge/sweep/exposure/phase/death transitions, weapon ownership, empty special weapon fallback, automatic MG belt replacement death collision, real physics hitscan damage, and wall occlusion. It does not assess navigation quality or player enjoyment. `test_visual.gd` captures the actual engine meshes from the FPS camera with neutral lighting; `review/fps.png` is separate from generated concept art.

Fixed meshes are joined per animated pivot: 8–9 mesh objects per character, 9 for the MG (8 independently moving rounds), 1 each for shotgun and flare pistol. Material surfaces still require separate draw calls; these object counts are not a GPU draw-call claim.
