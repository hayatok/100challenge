# TENSAI asset ledger

These are original G1 stylized character studies authored in Python for Blender 5.2.1. The character models use no downloaded model, texture, scan, font, paid asset, or image generation service. The separately bundled UI font is listed below. Materials are an original flat palette. The editable geometry, material graph, named mesh parts, armature, actions, studio camera, and lighting are retained in `art/hero.blend` and `art/sentinel.blend`.

Regenerate from the application directory:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python art/create_art.py
```

The script clears a fresh Blender scene, builds both characters, exports selected character meshes and armature to `game/assets/models/*.glb`, saves originals, and renders actual mesh previews. Its NLA tracks are muted in the saved originals for a stable studio pose; unmute a track or assign the corresponding action to preview animation. Runtime GLBs contain all tracks. Camera, lights, and studio ground are excluded from GLB exports.

## Visual construction

The hero has a fitted vermilion jacket with raised lapels, navy trousers and faceted boots, ivory left shoulder, split coat tails on independent bones, a left forearm split-ring wire spool, short tied dark hair, and a right-hand single-edge sword. The white broken-circle back crest and asymmetry retain direction cues from behind. The sword's center ridge, narrow fuller, and incomplete circle guard repeat the ruin motif. The sentinel shares the visual language but uses indigo underlayers, two broad shell shoulders, a layered breastplate, an enclosed white helmet with a dark visor recess, and an indigo crest.

Cross-section lofts and extruded polygon panels are deliberately angular, rather than stacked default cubes or capsules. First-render review led to a rear insignia and clearer facial marks. An action render then exposed backward arm posing; bone-local axes were inspected and arm/torso rotations corrected before final export; the rear render confirms that split tails remain separate silhouettes.

| Source mesh count | Hero | Sentinel |
| --- | ---: | ---: |
| Vertices before glTF triangulation | 1121 | 783 |
| Polygons before glTF triangulation | 926 | 603 |
| Separate editable mesh parts | 51 | 43 |
| Joints | 18 | 18 |
| Height including hair/crest | 1.82 m | 1.98 m |

The models are authored Z-up, facing Blender +Y; glTF export converts them to Y-up facing -Z. Boots start at 0.025 m, leaving a small clearance around the controller's ground origin. Source metadata is in `art/asset_metadata.json`.

## Rig and animation

Each character has a real exported skin with `JOINTS_0` / `WEIGHTS_0`, one armature, and 18 joints: root, hips, spine, head, plus left/right upper arm, forearm, hand, thigh, shin, foot, and coat. Mesh pieces use rigid one-bone weights to retain the cut-paper/faceted treatment. This is bone-driven segmented deformation, not a soft organic skin; foot bones are retained for later dedicated foot articulation. Sword, guard, fuller, and grip share the right hand's weights, so they cannot detach through independent animation. Coat tails have their own bones.

Both GLBs contain these exact separate animation names: `idle`, `run`, `slide`, `jump`, `fall`, `wire`, `slash_1`, `slash_2`, `slash_3`, `launch`, `plunge`, `hurt`, `death`. Idle breathes and shifts the torso; run counter-swings limbs and raises knees; slide lowers hips and extends a leg; wire extends the launcher arm; slashes twist the torso with separate sweeps; launch lifts the sword; plunge points the sword down; death lowers the full rig. Actions are sampled at 30 fps with 54 transform channels per clip. Nominal durations are listed in the metadata; exported durations run from first to last sampled frame and may differ by one frame. Idle/run should be set to loop by the Godot runtime, since standard glTF has no loop flag.

## Evidence and remaining work

`hero_preview.png`, `hero_rear_preview.png`, and `sentinel_preview.png` are Cycles studio renders of actual meshes, not gameplay or concept images. `hero_slash_preview.png` uses frame 10 of the authored slash action from the saved hero original, reproduced with `blender --background --python art/inspect_motion.py`. GLB JSON inspection confirmed one skin, 18 joints, and all 13 named clips in each file. Parent integration is responsible for Godot import, actual gameplay-camera review, and playback/transition verification.

These are G1 art and motion studies. They do not yet establish finished character quality. The rigid joint treatment, contact timing, locomotion speed matching, clipping in blended actions, and the readability of every combat pose need review at gameplay speed. There is no root-motion locomotion, cloth simulation, texture painting, finger rig, facial animation, IK, or motion capture. The sentinel deliberately shares the base action library at this stage; role-specific attack animation remains later work.

## Synthesized audio

All six WAVs in `game/assets/audio/` are original numerical synthesis from `scripts/make_audio.py`, generated with Python standard-library math, deterministic noise (`random.seed(178)` reset per sound), envelopes, and PCM serialization. There are no downloaded recordings, sample packs, external music, speech, or generation-service inputs. These assets do not introduce a third-party audio license; this ledger does not grant a new license for the project's original work.

| File | Duration | Construction |
| --- | ---: | --- |
| `slash.wav` | 0.23 s | Decaying noise and falling sinusoidal sweep |
| `wire.wav` | 0.35 s | Rising sweep and light noise |
| `impact.wav` | 0.38 s | Low falling tone and noise |
| `dash.wav` | 0.25 s | Noise and 190 Hz tone |
| `chime.wav` | 0.80 s | 440/660/880 Hz chord |
| `wind_music.wav` | 16.00 s | Open-fifth pads, repeating upper plucks, and synthesized low pulse |

All files were inspected with the WAV header reader: mono, 24,000 Hz, signed 16-bit PCM. The generator bounds each sample to ±0.92. Regenerate with `python3 scripts/make_audio.py`. This establishes source and file format, not listening quality or finished sound design. The source contains a fade at both ends of the music buffer; a repeated buffer is not a phase-continuous seamless composition.

## Bundled UI font

`game/assets/fonts/NotoSansCJKjp-Medium.otf` is an unmodified Noto Sans CJK JP Medium, copied from the generic font already bundled in `2026-10-19/game/assets/fonts/`. It is a shared third-party typeface, not reuse of that application's original character/world/game artwork. The new and prior OTF SHA-256 values were compared and are identical:

`dd523e580e3413c480b2d701bf64e534c20f8419e3cfb6a44c2bdcd8d2a6c052`

The OTF name table records version `2.004;hotconv 1.0.118;makeotfexe 2.5.65603`, copyright `© 2014–2021 Adobe (http://www.adobe.com/).`, and SIL Open Font License 1.1. The bundled full license is `game/assets/fonts/LICENSE.txt`; the official upstream [Noto CJK Sans license](https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE) verifies the license family and conditions. The font has not been subset, renamed, or modified for TENSAI. Preserve both the copyright notice and complete OFL text when distributing it.

## Engine and distribution notices

Godot 4.7.2 is distributed under MIT and includes third-party components with their own notices. Blender is a creation tool and is not embedded in the exported game. Character exports do not embed Blender code. See [THIRD_PARTY.md](THIRD_PARTY.md) for verified sources, complete Godot MIT and font OFL text, and the implemented accessible packaging layout. Final macOS archive signature and notice-byte checks passed, and all five Web license files returned HTTP 200 with matching bytes. See the verification record for the tested artifacts.
