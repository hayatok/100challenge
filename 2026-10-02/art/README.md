# BLACK RELAY / 黒の中継局 — original asset kit

Seven original, texture-free, low-poly models generated and exported in Blender 4.3.2 for Godot 4.7.2. All geometry and materials are original; no downloaded assets, franchise models, textures, or fonts are included in the game assets.

## Runtime files

| File | Design | Use |
| --- | --- | --- |
| `models/enemy_walker.glb` | HUSH | Upright cable skeleton with a split ivory signal mask |
| `models/enemy_crawler.glb` | SKIP | Low quadruped cable spool with one amber optic |
| `models/enemy_beacon.glb` | CHOIR | Three suspended masks above a hanging cable skirt |
| `models/boss_relay.glb` | THE CARRIER | Relay shrine, exposed amber heart, circular ceramic frame and three mask hubs |
| `models/relay_cabinet.glb` | Maintenance cabinet | Voltage meters, lamps, louvres, cabling |
| `models/hazard_gate.glb` | Signal-station gate | Separate frame and moving barrier panel |
| `models/conduit_bundle.glb` | Armoured conduits | Three bent pipes with couplers and mounting brackets |

## Integration

- GLB coordinates: +Y up, front toward +Z. Units are metres. Creature roots are at ground centre. CHOIR intentionally floats above its ground root
- Individual named component pivots are retained for runtime transform animation. `head`, `core`, `arm_L`, `arm_R`, `leg_*`, `mask_left`, `mask_right`, and `halo` names may have Blender numeric suffixes. Use a prefix search when locating a component
- Materials are simple opaque PBR colours. Amber emission is exported and verified by Godot. No textures, transparent materials, skeletons, baked animations, physics colliders or scripts are embedded
- Imported flat-face normals intentionally preserve a low-poly manufactured appearance
- HUSH is approximately 1.89m high, SKIP 0.8m, CHOIR 2.4m, and THE CARRIER 4.1m. The preview shrinks THE CARRIER to 61% for a readable contact sheet; the GLB is full scale
- The gate is 3.68m wide. Scale its X axis for a wider doorway; it does not span the entire 8m station corridor by default

## Reproduction

Run from any directory:

`blender -b --python art/source/generate_black_relay.py`

After generation, copy `art/models/*.glb` into `game/assets/models/` and run the project import/tests. Committed runtime models are under `game/assets/models/`; `art/models/` is only generated output.

The generator exports the seven GLBs, updates `asset_manifest.json`, saves the editable Blender showroom, and renders `previews/black_relay_creatures.png`. Blender's CPU renderer is used with denoising disabled for compatibility with this installation.

Each `source/*_final.blend` contains an isolated final asset at its authored origin and scale. Running the generator writes `source/black_relay_asset_showroom.blend` containing all seven assets and a lit creature preview. Environment props are hidden for the contact sheet. Original unscaled asset generation is in the Python script; the showroom has intentional display positions/scales. Only isolated final source assets are included with the project.

## Validation

All seven final GLBs imported and instantiated successfully in Godot 4.7.2 using the Compatibility renderer. The test checks mesh nodes, surfaces, vertices and emissive material import. See `validation/godot_import_report.json` and the reproducible `validation/validate.gd` script. The contact sheet was rendered in Blender and visually inspected. These are asset-level checks, not a claim of full game QA.

## License

CC0-1.0. Original geometry, procedural source and materials are dedicated to the public domain. There are no external asset attribution obligations. See `LICENSE.txt`.
