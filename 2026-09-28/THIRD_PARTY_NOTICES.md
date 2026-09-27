# Third-party assets and software

Runtime 3D assets were downloaded from their original author uploads on OpenGameArt on 2026-09-28. No assets from The Typing of the Dead are included.

| Asset | Author / original page | License | Changes |
| --- | --- | --- | --- |
| Male City Zombie | Rikindle3D — https://opengameart.org/content/male-city-zombie-ready-for-use-in-game-engines | CC0 | FBX converted to GLB, animation tracks combined and walk arm pose corrected |
| Pistol | loafbrr_1 — https://opengameart.org/content/pistol-5 | CC0 | glTF converted to GLB, detached magazine hidden in scene |
| FPS arms (rigged only) | para — https://opengameart.org/content/fps-arms-rigged-only | CC0 | Blender converted to GLB; right arm selected, dark material and positioning applied |

Detailed provenance, SHA-256 hashes, source downloads and reproducible conversion notes: `docs/CHARACTER_ASSETS.md`.

Three.js: MIT, https://github.com/mrdoob/three.js/blob/dev/LICENSE . The dependency package contains the original license. Vite, TypeScript and oxlint are development dependencies under their respective package licenses.

Noto Sans JP / Noto Serif JP: SIL Open Font License 1.1, served from Google Fonts with local Japanese font fallbacks. https://fonts.google.com/noto/specimen/Noto+Sans+JP and https://fonts.google.com/noto/specimen/Noto+Serif+JP .

The environment meshes and canvas textures, Japanese phrases, UI and supplemental low-frequency audio sweeps are original to this app. The approved generated reference image is a concept reference and is not used as a runtime background.

## Alpha audio additions

- **Gunshot Sounds**, © 2009 **Vincent Sevedge**. Source: https://opengameart.org/content/gunshot-sounds . **Creative Commons Attribution 3.0 Unported**: https://creativecommons.org/licenses/by/3.0/ . Three CZ-52 shots were extracted, equalized, compressed, faded, gain adjusted, and encoded as MP3. The archive license is used even though the listing says CC0. No endorsement is implied.
- **Impact Sounds**, **Kenney**, CC0. https://kenney.nl/assets/impact-sounds . Five unmodified impact samples.
- **Darkness Road Remake**, **MintoDog**, CC0. https://opengameart.org/content/darkness-roadremeke . Unmodified loop, filtered dynamically by the game.

See `docs/ALPHA_AUDIO.md` for source and output hashes and reproducible processing.

## Alpha character additions

- **Thin Zombie [Awake Zombie Asset]** by **Rosswet Mobile** (submitted by dogchicken), https://opengameart.org/content/thin-zombie-awake-zombie-asset , licensed under **CC BY 3.0**, https://creativecommons.org/licenses/by/3.0/ . Modified for this game: Blender source converted to GLB, bundled texture reconnected, selected animations exported, and model scale adjusted. No endorsement is implied.
- **3d Zombie grandma - walking rigged**, **Petrov_the_blind**, CC0. https://petrov-the-blind.itch.io/3d-zombie-grandma . Converted to GLB, mesh simplified, texture connected, scale adjusted.
- **3D Horror Game Monster**, **City Building Game Art**, CC0. https://opengameart.org/content/3d-horror-game-monster . FBX walk, idle and run combined as GLB, texture connected.

See `docs/ALPHA_CHARACTER_ASSETS.md` for source and output hashes and conversion scripts. The in-game credits include required attribution and license links.
