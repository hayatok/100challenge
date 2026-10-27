# v0.3 Sunlit Tideglass portrait family

## Production brief

Purpose: replace the dark, granular legacy conversation/harbor portraits with four coherent adult adventure illustrations. Main UI display is approximately 180 by 240 CSS pixels on a 390 by 844 phone; desktop may display larger. This is source-asset work. Native-scale composites are asset QA, not actual game screenshots or human playtesting.

Use polished anime RPG illustration: confident fine outlines, smooth opaque color planes, controlled cloth folds, clean eyes and warm skin. Light comes from upper left, matching the turquoise sea, pale limestone, honey timber and teal canvas of Sunlit Tideglass. Preserve adult proportions and practical recovery-worker clothing. Favor a readable face, natural hands and one restrained friendly gesture over tiny accessories. Each woman must have a distinct face, build and temperament.

- Isana: adult in her late twenties, chestnut high ponytail with teal ribbon, amber eyes, warm open smile, ochre waterproof coat, dark work trousers, teal neckcloth, brass guild badge, recovery satchel.
- Ritsu: adult in her early thirties, tall athletic build, silver asymmetric bob, blue eyes, composed angular face and restrained smile, navy diving suit, red scarf, compact air tanks.
- Kohaku: adult in her late twenties, sturdy build, brown skin, copper curls, green eyes, broad cheerful face, forehead goggles, rust workwear and teal accents.
- Sui: adult in her late twenties, long black hair, light skin, pale violet eyes, slender oval face, calm curious expression, ivory hooded coat, teal layers and survey satchel.

Composition: isolated single character, knees-up three-quarter view, large face, all hair and both hands intact, margin around the silhouette. Prefer free hands; passive straps/role gear may remain. Deliver genuine transparent RGBA, no scenery, shadow plate, white fill, text, labels, frames or signature. Exclude grain, oil-paint stipple, harsh black shading, young/child proportions, generic identical faces, extra fingers or fused hands. References lock identity/costume; their old grain and dark treatment must not carry over.

## Process and acceptance

Built-in image generation only. Approved cap: five calls total, four character sources plus at most one representative correction. First inspect Isana on cream and teal at 180 by 240 before continuing. Preserve originals outside res:// in `.scratch/versions/v03/portraits/`. Production images are 768 by 1024 RGBA under `game/assets/art/v03/portraits/`; only non-destructive crop, padding and uniform resize are allowed. Do not paint or reconstruct pixels outside image generation.

Record prompts, generated paths, copied source paths, SHA-256, normalization bounds, alpha statistics, normalized face rectangles and individual QA in the asset manifest. Generated material uses OpenAI built-in image generation; no external artwork or third-party license is asserted. Review project/provider terms before redistribution if necessary. Game integration and actual native/Web checks belong to the parent integrator. Original generated PNGs must stay outside exported res://.

## Source QA outcome

Five built-in calls were used: four original portraits and one Sui framing correction. Sui's initial right hair was clipped; the corrected source restores a complete hair silhouette. The rejected source remains in the generator output directory, with its prompt recorded in scratch. All four selected files are 768 by 1024 RGBA with transparent and opaque pixels; SHA-256 and original generator paths are in `game/assets/art/v03/portraits/manifest.json`.

Inspected `.scratch/versions/v03/portraits/family-native-qa.png`: four individual 180 by 240 composites on both cream and teal. Adult faces, clear eyes, natural hands, characteristic hair and costume colors remain readable. The women differ in face, build and expression. Lower knee/thigh boundaries are intentional portrait crops. Ritsu's outer scarf meets the original right source edge; its hands and hair are intact. Minor inherited worn-fabric texture remains, but the skin/eye rendering is smooth and daylight is substantially clearer than the legacy dark portraits. No white backing, text or visible alpha plate was found in these composites.

The manifest includes approximate normalized face rectangles (x, y, width, height), excluding most hair; expand them when making head crops. No gameplay code was changed. Actual Godot/Web placement, overlap, UI cropping and human acceptance remain integration checks. The parent integrator owns the mandatory Astra review for the complete change, including these files.
