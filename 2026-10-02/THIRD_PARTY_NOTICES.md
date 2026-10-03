# Third-party notices

BLACK RELAY code, setting, procedural environment, earlier signal-horror character models and synthesized audio are original work created for this project. The urban slice adds the licensed character, weapon, surface and recorded-audio assets below. No proprietary franchise assets are included.

## Godot Engine

Godot Engine 4.7.2, copyright Godot Engine contributors, MIT license. Exported runtimes contain the engine and its bundled third-party libraries. See https://godotengine.org/license/ and https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt .

## Noto Sans CJK JP

NotoSansCJKjp-Medium.otf is distributed under SIL Open Font License 1.1. Complete notice: `game/assets/fonts/LICENSE.txt`. Generic font reused from this repository's licensed font bundle, not copied game artwork.

## DejaVu Sans Mono

DejaVuSansMono.ttf, Bitstream Vera/DejaVu license. Complete notice: `game/assets/fonts/DEJAVU-LICENSE.txt`.

## Original assets

- Blender models: `art/LICENSE.txt`, manifest `art/asset_manifest.json`
- Synthesized audio: `game/assets/audio/ORIGINAL_AUDIO_LICENSE.txt`, manifest `game/assets/audio/audio_manifest.json`

The complete runtime-reported Godot MIT and bundled dependency license texts for this exact engine version are also included in `docs/licenses/GODOT-LICENSE.txt`. The macOS ZIP includes readable copies of all required notices alongside the app bundle.


## Urban slice licensed character and weapon art

- **Male City Zombie, Ready for use in Game Engines.**, **Rikindle3D**, [official source](https://opengameart.org/content/male-city-zombie-ready-for-use-in-game-engines), **[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)**. Adapted from the repository's licensed FBX-to-GLB conversion. This slice adds original muted skin/cloth texture recolors, softer nonmetallic material response, bent-arm idle corrections, and a reversed/retimed forward death with arms settling to the pavement. Model/rig/sculpted facial detail and source animation remain credited third-party work
- **Pistol**, **loafbrr_1**, [official source](https://opengameart.org/content/pistol-5), **CC0 1.0**. Current author archive README confirms Creative Commons 0. Adapted from the licensed GLB conversion with a blued-steel albedo bake, steel/polymer response, removal of loose spare magazine and first-person grip fitting
- **fps arms (rigged only)**, **para**, [official source](https://opengameart.org/content/fps-arms-rigged-only), **CC0 1.0**. Original underlying mesh and skin texture made with **MakeHuman**, credited by the author; [MakeHuman core-asset license](https://static.makehumancommunity.org/about/license.html). Hands/forearms are posed and baked for a two-handed pistol grip. Cloth material and rounded cuffs are original additions
- **Thin Zombie [Awake Zombie Asset]**, **Rosswet Mobile** (submitted by dogchicken), [official source](https://opengameart.org/content/thin-zombie-awake-zombie-asset), **[CC BY 3.0 Unported](https://creativecommons.org/licenses/by/3.0/)**. Modified for this game: Blender source converted to GLB, bundled texture reconnected, selected animations exported and model scale adjusted; this slice reuses that licensed converted asset for runner variation. No endorsement is implied

## Urban slice surface textures

- **Worn Asphalt**, **Amal Kumar**, [official source](https://polyhaven.com/a/worn_asphalt), **CC0**
- **Worn Shutter**, **Dimitrios Savva**, [official source](https://polyhaven.com/a/worn_shutter), **CC0**

Each uses unchanged official 1K JPEG diffuse, OpenGL normal and roughness maps. Runtime UV repeat, surface response and lighting are changed by this game. [Poly Haven license and redistribution terms](https://polyhaven.com/license)

## Urban slice recorded effects

- **Gunshot Sounds**, copyright 2009 **Vincent Sevedge**, distributed by OGA uploader Tabasco, [official source](https://opengameart.org/content/gunshot-sounds), **[CC BY 3.0 Unported](https://creativecommons.org/licenses/by/3.0/)**. One CZ-52 shot was extracted, equalized, compressed, faded, gain adjusted and encoded as MP3 by the repository's licensed audio conversion; this slice reuses that output as `game/assets/audio/shot.mp3`. The author's downloaded archive explicitly states CC BY 3.0, which is used conservatively despite the listing's CC0 label. No endorsement is implied
- **Impact Sounds**, **Kenney**, [official source](https://kenney.nl/assets/impact-sounds), **CC0**. The original heavy body and heavy metal OGG samples are reused unchanged as `impact_body.ogg` and `impact_metal.ogg`

Official author pages and archive notices were independently rechecked on 2026-10-02. Exact provenance, source/license links, modification details, verified Godot rig contract and output hashes: `docs/URBAN_ASSETS.md` and `art/source/city/provenance.json`. Required author license observations are included under `art/source/city/licenses/`. Raw author source archives are not included in runtime exports. No author endorsement is implied.
