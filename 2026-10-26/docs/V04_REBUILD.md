# v0.4: expedition rebuild

## Goal and evidence

On 2026-10-29 JST the user resumed development and requested substantial redesign of play, graphics, staging and HUD, continuing in versions until stopped. Commercial quality is the target; a passing test suite or publication is not acceptance of that target.

Baseline: published v0.3, main e1a83a7, release-2026-10-28-2. Start-of-work Git tree was clean. Current work uses codex/shio-major-update. Preserve the existing public and local player saves. Use new QA origins.

The current expedition leaves only about 328px of unobscured world at 390x844. The brand, large stats card, objective ribbon, overlaid movement dock and permanent radio compete for space. Its camera does not account for those overlays. Read-only code audits also found long cleared return walks, a repeatable safe landing-supply sale loop, stat-only weapon/crew differences and no shared action prediction API. A separate local v0.3 browser pass at localhost:4341 confirmed the five-turn, no-combat scrap/medicine return condition. These are structural/operation findings, not human evaluation of fun.

## Intended experience

Read a compact piece of the flooded town, judge the announced threat, spend a tool or a worker technique to make a route, and decide whether the cargo already carried is worth returning with. The main delivery should not require exploring every optional encounter. The next district must change the geometry and decisions.

## Implementation boundaries

1. New departures use encounter-v04 compact district maps, approximately 17x19, with three authored connected encounter areas, a main delivery in the middle area and optional valuable salvage farther in. Main cargo plus some safe return route remain reachable for every seed. A visible bombable shortcut or a guarded alternate return offers a costed route choice. Do not add surprise spawns on objective pickup. Landing alone must not yield endlessly renewable sale cargo; the free loan knife keeps retry possible.
2. Keep deliberate cardinal movement/bump attacks, existing tools and full carried-item loss. Add one shared crew action with three finite uses per expedition. Its four variants change an existing action: Isana moves two clear cardinal cells in one turn; Ritsu braces against the current announced hit; Kohaku shoves an adjacent foe; Sui surveys nearby blocked sight. A targeted action requires explicit direction. Invalid or ineffective use spends neither resource nor turn. Exact limits and outcomes must be visible in crew_info and verified in tactical fixtures.
3. Pure Rules APIs: threats(state) returns visible threat dictionaries with enemyId, kind, cells (x/y), text and phase. preview_action(state, action) returns valid, reason, damage, resourceCost and destination (x/y) using the real resolution path on a copy, never a second damage implementation. crew_info(state) returns name, description, charges, maxCharges, targeted and available. Legacy runs may expose informational queries but cannot receive new actions or changed effects.
4. Schema 3 explicitly tags migrated in-flight runs legacy-v03 and preserves all old map cells, positions, HP, equipment, loot, enemies, knowledge and timing. Exact v1/v2 validators remain frozen. Old runs use their existing rules until completion; only the next departure uses the new generator. Keep the save key and write an exact pre-v3 raw backup before overwriting any valid v1/v2 source. A failed backup refuses the write. Malformed/unsupported saves remain untouched. Tests must cover migration and legacy action equivalence, not only fresh starts.
5. New run presentation metadata may include encounters and landmarks; specify and validate their exact JSON shapes before exporting them. Landmarks use the existing kind/x/y shape and must match actual blocked/water anchors. The board reads new run anchors and legacy CampaignData anchors separately.
6. Replace the expedition shell. Phone HUD is about 68 logical pixels plus a 28px purpose strip; the final controls occupy 180 logical pixels outside the board to keep every primary button at least 44 CSS pixels on the small phone. Remove the permanent brand/header and radio card from field mode. Aim for at least 500px unobscured world at 390x844 and 430px at 360x740. Use 14-16px temporary feedback, real tool/technique controls and high-contrast threats. Desktop uses a compact 260px sidebar with a full-width wrapping objective and a separate turn/value row, beside a large field.
7. Board API remains present(state, events, reduced_motion), cell_selected and visible-grid coordinates. Add set_playable_rect(Rect2) if the shell overlaps world; fit the camera to the actual playable area and keep the player plus impending threats readable. The board may display the shared threat/preview data but cannot advance time, choose hidden loot or own save state.

## Ownership

- Rules worker: rules.gd, world_data.gd, campaign_data.gd, save_store.gd, new pure helper modules, rules tests and dedicated migration/tactical tests. Coordinate any new metadata/API shapes with the parent and board worker.
- Board worker: board.gd, board.tscn, world_effects.gd, shaders and district scenery resources. Keep actor.gd and main.gd unchanged.
- Parent: main.gd, new expedition HUD scene/script, UI theme, UI/store tests integration, version/package metadata, docs, GitHub tracking, combined checks and actual browser operation.
- v0.5 actor/art work follows the new playable field. It is a separate version, not a claim that procedural motion on two poses is finished character animation.

## Done when

- Distinct compact routes and both early return/optional continuation are actually operable; representative charge, shove, brace, lure and shortcut fixtures demonstrate different costs/outcomes.
- Threat/prediction statements match resolved turns, invalid actions are free, full loss/one-time extraction remain correct, and strict old-save migration is tested.
- Actual Web play covers departure, tools/crew action, objective return, optional risk, death/retry, reload and one district unlock. Inspect all four map layouts, phone/small/desktop, reduced motion, focus/modal pause and input pacing.
- Compare before/after field allocation, motion and feedback with captured real screens. Automated operation cannot establish human fun. Record the limitations and use the next iteration to address concrete failures.
- Appropriate checks, Japanese run/verify, mandatory Astra review and current-head CI pass. v0.4 plus v0.5 form the next Pages pair; preserve the reviewed tag-based route and compare the public files to the same-run Linux artifact.
