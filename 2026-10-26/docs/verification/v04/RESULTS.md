# SHIOGAERI v0.4 verification

Recorded 2026-10-29 JST against the published v0.3 baseline e1a83a7. The user resumed development and requested major changes until stopped. This version rebuilds expedition structure and the field presentation; v0.5 remains the second version of the next Pages pair. Public v0.3 has not been replaced by this local checkpoint.

## Resulting play and presentation

New departures use compact 17x19 authored encounter layouts. Each district has a middle delivery and an optional deeper salvage cache, a visible breakable shortcut and a traversable elevated flank. Landing-only return yields no renewable sale cargo. Isana's two-cell movement, Ritsu's brace, Kohaku's shove and Sui's temporary survey each have three uses per new expedition. Invalid/ineffective uses spend neither a turn nor a charge. Direction buttons derive incoming damage from the actual rule resolver on a copy; board threats use the same visible-enemy query.

The expedition has an editable dedicated HUD scene, with instruments, purpose, world and controls in separate layout regions. Idle unobscured field bounds measured by native UI tests are 374x530 CSS pixels at390x844 and345.95x464.69 at360x740. Primary controls remain at least44 CSS pixels. Temporary feedback can wrap and briefly use more vertical space. Desktop uses a260-logical-pixel sidebar; a full-width wrapping objective and separate turn/value row prevent the return instruction from being ellipsized. An optional desktop direction pad fits vertically without widening the sidebar.

The board now shows quiet limestone planes, continuous raised edges and shadow, real water gaps, narrow timber crossings, distinct district resources, visible breach cracks and outlined directed threats. This is a readability and spatial-layout rebuild. The existing two-contact directional actors remain in this version; skeletal-animation experiments under ignored v0.5 scratch paths are excluded.

## Automated and native evidence

Final `npm run check` passed with Godot4.7.2: legacy rules5328/0, tactical/migration3907/0, UI/store643/0, import and single-thread Compatibility Web export. See [combined output](check-output.txt). Root `npm test` passed38/38. `git diff --check` passed.

The tactical suite checks32 seeds x4 districts for topology, delivery/optional cargo, guarded supplies, non-farming landings and reachable dry routes. Real starter-item campaigns cover all four districts on seeds0/7/31 without injected cargo. Fixtures cover charge/dodge, brace, shove, lure, breach, invalid actions and truthful preview damage. The layouts are authored; seeds vary surface and an optional guard's facing. These checks do not establish procedural replay variety.

All20 original UI/store/campaign test functions remain. Old fixed-coordinate scenarios explicitly use valid legacy-v03 fixtures; their frozen actions migrate through the real facade. Additional tests use normal compact departures, three-use techniques, cancellation/no-turn menus, save/reload, incoming-damage labels, phone touch bounds, objective continuity after a real delivery/unlock, far-cell guidance and responsive layout round trips. Persistent feedback clear and actual Timer timeout restore both desktop objective and summary without changing game state.

The board probe checks19 size/state conditions. A separate28-check native fixture probe validates the four primary landmarks, their kind, blocked/water anchors, visibility and state invariance. Static images are explicitly labelled fixtures: [quay](static-fixture-quay-primary-lighthouse-native390x530.png), [market](static-fixture-market-primary-market-native390x530.png), [canal](static-fixture-canal-primary-clinic-native390x530.png), [observatory](static-fixture-observatory-primary-pump-native390x530.png). They are not evidence that those locations were reached through Web gameplay.

## Actual exported Web operation

Agent-operated testing used owned QA origins localhost:4341 and localhost:4342, preserving the existing public and older local player origins. Read-only DOM measurement confirmed390x844,360x740 and1280x800. Screenshots and actions are operation evidence, not human fun or physical-device acceptance.

At4342, a fresh Isana packed five actual starter items, used a targeted two-cell technique, broke the central wall with a bomb, recovered the main core/scrap, took a real4HP wader charge, used a flare and a second movement technique, and returned after15 turns. The [settled receipt](first-return.jpg) showed five actual items worth94pt. Reload retained it. Delivering the core/scrap earned20G, restoration1/4 and market access; no cargo was injected.

Sui then selected the unlocked market, packed five stored items and used survey on turn3 (charges2/3). Reload preserved the turn/HP/inventory/charges and showed the current market restoration goal even with no explicitly tracked contract. A bomb opened the shortcut. Sui killed the middle guard and recovered two gears plus two scraps, reaching turn15 with8/12 items and20HP. Continuing north cost more combat/turns; the optional cache was actually opened on turn27, yielding two pearls, a harpoon and a bomb:12/12 items,13HP. See [deep salvage](deep-salvage.jpg).

For a deliberate loss test, Sui moved to low ground at turn31 and waited through the rising tide. Death on turn44 showed [all12 carried items lost,209pt](loss-t44-12-items.jpg). This was an intentional test, not a failed attempt to survive. Reload retained that exact result. The [harbor afterwards](harbor-after-loss.jpg) kept restoration1/4,20G and the one stored item; survival was1/2. Departing with no carried gear supplied the free loan knife, turn0, full HP and refreshed3/3 techniques. The [small-screen retry](retry-small-final.jpg) remained operable.

The original five-turn v0.3 landing-supply route was first reproduced on4341. After upgrading that origin, [Continue resumed](legacy-resumed.jpg) the same25x25 map, turn5,24HP and3 carried items, with old-run techniques unavailable. The old run extracted two stored items worth14pt; the borrowed knife was returned separately. The [next departure](legacy-next-new-run.jpg) used the new17x19 map and3/3 technique charges. No player storage was cleared to force this transition.

At360x740, tapping a distant visible floor from a hidden-feedback state displayed [the explicit no-auto-move guidance](small-field-feedback.jpg) without changing turn18, HP17 or8 carried items. Desktop inspection found an ellipsized objective, which was corrected and regression-tested; the [final desktop field](desktop-final-objective.jpg) shows its complete goal and separate summary. Optional touch controls, technique-modal cancellation, inventory, settings and live reduced motion were operated. Error-level logs for both owned QA tabs were empty at the final inspection.

## Corrections and Japanese review

The mandatory ai_slop_reviewer / gpt-6-astra initially found two issues: pre-added landing anchors prevented the primary district landmark from being placed, and a distant-cell instruction was written into a hidden feedback label. An explicit primary-placement flag and `show_feedback()` resolve them, with topology/native-fixture and actual Web regression evidence above. The reviewer rechecked those fixes and reported no findings. Its final follow-up also covered the objective fallback, desktop text layout and checkpoint documentation, and reported no findings. The reviewer inspected code, records and saved images; it did not independently run tests or operate the browser.

Changed Japanese-bearing sources and README have direct Bash CLI lint/run/verify records with final hashes, summarized in [Japanese review](japanese-review.json). Originals were retained before edits. Numeric technique limits, version/publication state and old-save conditions were compared with the implementation and actual screens. GDScript identifiers, required colons and precise gameplay wording were retained; lint candidate counts are not quality scores. The frozen legacy module preserves its old Japanese literals.

## Limits and next version

The game is still a development build. The compact maps remain authored and repeatable, cleared return corridors can become quiet, and actor motion is still the prior two-contact family. Harbor/result layouts and landmark identity need the larger v0.5 presentation work. Physical iPhone/Android, Safari, audio listening, endurance and human first-play enjoyment remain unverified. The rule campaigns and labelled native fixtures do not constitute a full Web campaign. Commercial quality is a target, not a conclusion from these checks.

Current-head CI, reviewed merge, the paired v0.4+v0.5 Pages tag and public/Linux-artifact checks will be recorded at the publication boundary. No new release tag or public deployment is claimed here.
