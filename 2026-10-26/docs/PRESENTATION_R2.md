# Presentation revision 2: Sunlit Tideglass

## Goal and context

The user rejected the first playable as sparse, dark and visually plain, and requested a much richer commercial-quality direction. Raise the quality of the complete game presentation: title, harbor, expedition, inventory, settings and results. Evaluate the actual game in motion, not the quantity of checks. The existing full-inventory loss, turn-based decisions and four adult recovery workers remain the core.

Baseline is commit `d240b3a`. The worktree started clean. Read PLAN, ART_DIRECTION and CONTRACT for the existing rules. Existing browser saves, including ongoing expeditions, must survive. Test new gameplay on a separate localhost port/origin and use `--qa` for native fixtures. Never clear a player's saved progress.

## Art direction

The town is seen during a bright break in the weather: turquoise sea, pale limestone, honey-colored timber, white stucco, coral roofs and teal canvas. Warm sunlight comes from the upper left. Small bright flowers, ropes, market awnings, fishing boats, foam and gulls make the harbor feel inhabited. Ruins and rising water still create tactical danger; the entire scene must not be darkened to communicate it.

Use polished hand-painted anime adventure art with confident outlines, simplified readable material planes and controlled detail. Keep existing portraits and character identity: Isana's chestnut ponytail/ochre coat; Ritsu's silver bob/navy suit/red scarf; Kohaku's copper curls/brown skin/rust workwear; Sui's long black hair/ivory coat/teal clothing. All are adults. Field miniatures may use about 3.5-head proportions for readable silhouettes; portrait art retains adult proportions. Do not imitate a named artist or reuse another game's artwork.

UI is nautical enamel and warm expedition paper: ink `#183e52`, muted `#607b87`, cream `#fff8e5`, paper `#f7edcf`, outline `#99c7c4`, teal `#40b7bd`, coral `#f18473`, amber text `#a96a20`, primary amber fill `#f4c05d`. Use deep outlines, deliberate shadows, cut corners, wave rules, compass motifs and small rivets. Keep Noto CJK and the recorded license. Body 16 logical pixels, secondary 13; 52-pixel controls remain at least 44 CSS pixels on the small target. Never bake text into generated art.

## Asset family and contracts

New art lives in `game/assets/art/r2/`; preserve all previous assets and their provenance. Use built-in GPT image generation after this direction has been recorded. Approve the bright harbor as the first family target before generating related art. The art owner may make up to five calls in this pass, including one corrective edit if necessary; report a need for a different scope instead of silently expanding it.

| File | Purpose and technical frame |
| --- | --- |
| `harbor-day.png` | Bright painted harbor panorama, wide landscape, no text/frames, readable sunlit town and open water. Use as family reference. |
| `terrain-day.png` | Four equal quadrants: pale stone floor, white/coral masonry, honey timber, clear turquoise water. Orthographic overhead materials; verify actual bounds and repeated appearance. |
| `props-day.png` | Transparent, separated lighthouse, fishing boat, market stall, old clinic facade, pump/workshop and flower/rope planter. Three columns/two rows are a request, not assumed slicing coordinates. |
| `crew-field.png` | Transparent, four separated adult field miniatures, same lighting/view/line weight and recognizable clothing, facing toward the camera. Verify real alpha and actual isolation. |
| `manifest.json` and `.tres` | Prompts, original paths, dimensions, alpha checks, crops and limits. Native AtlasTextures: `prop_lighthouse`, `prop_boat`, `prop_market`, `prop_clinic`, `prop_pump`, `prop_planter`, and `crew_isana`, `crew_ritsu`, `crew_kohaku`, `crew_sui`. Rects use inspected pixels, not an assumed generated grid. |

Source art is not accepted merely because generation succeeds. Inspect silhouettes, face/clothing identity, alpha and crops; inspect repeated terrain and native game scale. Missing or unsuitable parts must be recorded and revised, not disguised with an opaque box.

## Screen and feedback changes

- Title: bright harbor illustration, designed logo/nameplate, moving gulls/cloud glints and clear amber start action.
- Harbor: larger character stage, portrait selection controls, framed quote, illustrated item rows and readable carrying/equipment summary. Every action continues to transfer the actual item UID.
- Expedition: larger bright world; portrait/health strip, tide forecast, cargo and an objective indicator. Replace repeated movement-log noise with a concise contextual radio/hint panel. Surface real pickups, danger and tide changes.
- Inventory: illustrated item-slot grid plus selected-item details and explicit use/equip/drop controls. Keep equipment ownership and directional-use behavior. Menus cost no turns.
- Results: character and actual item receipts, a short arrival/loss sequence, animated item reveal and a real recovery-value counter. Retry stays usable during presentation. Empty receipts must remain truthful.
- Settings/help: the same paper/enamel framing, clear focus, readable controls and reduced-motion behavior.

Visual tiers: movement gets a quick stride/footplant and a soft ripple or dust puff; attack gets anticipation, a short slash, hit flash, particles and a number; rare loot gets a rising icon and warm rays; tide gets a wave sweep and forecast ribbon; return gets a warm celebration and item reveal. No routine shake or full-screen flash. Effects are presentation only, do not modify rules or drop deliberate inputs. Reduced motion removes camera shake, looping bob and large travel while retaining readable outcomes. Pause/hidden/focus loss stops presentation and sound.

The world keeps the `Board.present(state, events, reduced_motion)` and `cell_selected` contracts. Add `set_presentation_paused(bool)` for overlays. Keep tile coordinates/collisions and fog knowledge truthful. Architectural art belongs to wall/landmark anchors. Larger landmark silhouettes extend across cell boundaries: dim them over visible walkable cells and near the player foot, and render actors, loot and charge warnings above them. Known static landmarks may show their whole silhouette once their anchor is seen; hidden enemies and loot remain hidden. Tile collisions do not change. Avoid rebuilding the entire scene per frame. The audio owner retains `set_enabled`, `set_active`, `start_ambience`, `play_event`; add `set_scene(screen: String, tide: int = 0)` for harbor/exploration/result music layers.

## Done when

The same starting phone screen must visibly show a brighter, denser world and a deliberately designed game HUD. The first five minutes must include a clear discovery response, readable combat intent, distinct hit/pickup reactions and a character response tied to the actual result. Record the available pre-revision view and after views at 390 x 844, check 360 x 740 and desktop, and operate the exported Web build. The captured pre-revision embedded view is 280 x 607; do not label it as a same-size phone comparison. Distinguish full-resolution native fixtures from browser screenshots of a CSS-sized iframe scaled into the embedded panel. Keep automated state/save tests, meaningful input checks, native scene checks, Japanese review and mandatory Astra review. Passing these does not establish commercial release readiness: physical phone/Safari play, sound listening and human first-play acceptance remain explicit evidence needs. No deployment, merge or tag is part of this pass.
