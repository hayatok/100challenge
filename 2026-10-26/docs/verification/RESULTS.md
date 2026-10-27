# SHIOGAERI verification

Local vertical slice, checked on 2026-10-26 JST. No deployment, merge or release tag was performed.

## Automated checks

- `npm run check` in this app: Godot 4.7.2 import, 1,794 rule assertions, 34 UI/store assertions and single-thread Web export succeeded. The [engine output](godot-check.txt) is retained.
- Root `npm test`: 38 tests passed, including catalog registration and changed-app selection.
- `check_godot_project.py game`: 39 scene/resource/script files checked, zero errors and warnings.
- `git diff --check`: passed.
- The rule suite covers ownership, equipped-item loss, stash survival, extraction without duplication, loan equipment, item use, enemy intent, visibility, flooding and deterministic routes. Six seeds complete the supply-to-lighthouse-to-exit route with state validation and JSON save/reload after every action. An additional development sweep replayed the original save-failure route over 100 seeds with valid states throughout.
- The UI/store suite covers character selection, modal input blocking, five rapid deliberate inputs, held-key rejection, focus changes, invalid-action feedback, nonzero safe-area insets, atomic native storage and extraction receipts. It does not substitute for browser interaction.

## Browser interaction

The actual exported game was operated in the Codex in-app browser at `http://localhost:4316/`. Viewport sizes below are CSS pixels, not physical phone tests.

At 390 x 844, the checks included title/help, all four character selections, packing five items, departure, supply search, melee combat, enemy charge warnings, map and inventory scrolling, bomb use, tide changes, extraction, repair, death, retry and reload. A Ritsu run resumed from its last valid save after the save fix and completed in 68 turns: the bomb destroyed a wall and dealt 8 damage to the guard, the lighthouse core was recovered, and eight carried items reached the stash. The stash changed from 11 items to 9 after repair. A subsequent Isana run lost all five carried items, including the equipped knife and coat, on turn 33; the four items left in the stash survived. An empty loadout then received a loan knife and could depart again. Returning that loan produced a zero-item receipt.

Reload was checked both during ordinary exploration and while a wader was showing a charge intent: turn 30, HP 20/28, seven carried items and the warning were restored without a turn advancing. Menus and focus changes did not advance game time. After the repair, the next departure used the wider field of view.

A 837-to-790 CSS-pixel width change also switched the harbor across its layout breakpoint. At 360 x 740, harbor, inventory and expedition controls were checked for clipping and access to the primary action. At 1280 x 900, title, expedition, return confirmation, result and harbor were checked. Final touch targets use 52 logical pixels to remain above 44 CSS pixels at the small target. No new browser console errors were captured during the final inspection after 16:20 UTC. Safe areas were exercised with native UI insets of 44 at the top and 34 at the bottom; actual notched-device behavior remains unverified.

Selected screenshots are real Web output, not generated mockups:

- [Phone title](screens/web-phone-title.jpg), [prepared loadout](screens/web-phone-loadout.jpg), [Kohaku](screens/web-phone-kohaku.jpg)
- [Charge warning](screens/web-phone-telegraph.jpg), [bomb result](screens/web-phone-bomb.jpg), [core recovered](screens/web-phone-core.jpg)
- [Extraction](screens/web-phone-extracted.jpg), [repair](screens/web-phone-repaired.jpg), [loss](screens/web-phone-loss.jpg), [loan retry](screens/web-phone-loan-retry.jpg)
- [Small harbor](screens/web-small-harbor.jpg), [small inventory](screens/web-small-inventory.jpg), [small expedition](screens/web-small-expedition.jpg), [tablet breakpoint](screens/web-tablet-breakpoint.jpg)
- [Desktop title](screens/web-desktop-title.jpg), [harbor](screens/web-desktop-harbor.jpg), [loan confirmation](screens/web-desktop-loan-confirmation.jpg), [empty return](screens/web-desktop-empty-return.jpg)

The full expedition and early phone-title screenshots were taken before the final button-size and empty-return dialogue refinements. The small-screen, tablet and desktop layout captures were recorded after those changes. The fresh [trial panel](screens/web-panel-title.jpg) uses the normal embedded-panel viewport; the [final phone expedition](screens/web-phone-expedition-final.jpg) uses the 390 x 844 test viewport. Screenshot files use the JPEG format returned by the browser tool. Generated asset previews and native scripted fixtures were used during development and are not counted as browser playthroughs.

## Fixes found during verification

- Godot's new dictionary properties could create StringName keys for optional enemy state. Strict save validation rejected charge intent, lure target and other newly added fields. These are now inserted with String keys; validation remains strict. The per-action save/reload routes and consumable tests cover these transitions.
- Web startup was blocked by a bridge expression comparing a JavaScript boolean. Motion preference now crosses the bridge as a string, and the exported Web game starts normally.
- World objects rendered above inventory panels; the overlay now has an explicit higher layer.
- A time gate dropped deliberate rapid inputs. Input now resolves once per non-echo action event, with touch and physical-key mappings.
- Invalid actions now show their reason in the HUD. Full healing, an empty bomb target and a full bag retain both the item and the turn.
- Safe-area insets are read from CSS and applied to both the main frame and modals. Harbor layouts also rebuild when crossing their width breakpoint, including width changes smaller than 80 logical pixels.
- Return confirmation excludes loan items from the promised stash count; empty-return dialogue and result text reflect the zero-item receipt.
- The first [Linux CI run](https://github.com/hayatok/100challenge/actions/runs/40212184725) passed the rule and UI checks, then exposed a case-sensitive template path: Linux expects `godot/export_templates`, while macOS/Windows use `Godot/export_templates`. Setup now selects the directory for the host OS. The resulting CI status is tracked on the PR.

## Design and review

The applied skills include game-design and roguelike for choices and turn rules; create-game-assets for art direction and asset checks; Godot scene, GDScript, animation, UI, input, audio and export skills for implementation; game-feel for feedback; and save-systems for persistence boundaries. Art direction preceded the four character illustrations and terrain generation. Asset prompts and provenance are in `game/assets/art/asset-manifest.json`.

Japanese prose and UI strings were read against the implementation and checked with yomiyasu. Originals and detailed records remain in ignored `.scratch/japanese/`; the final verification summary is stored alongside this document. GDScript colons and exponent operators were retained as syntax. Parallel instructions and clear manual sentences were retained despite list/repeated-ending candidates. The check does not certify natural prose or unchanged meaning.

The required read-only reviewer `ai_slop_reviewer` (`gpt-6-astra`) confirmed the initial invalid-action feedback and safe-area fixes, with no additional findings in the follow-up. Its review was based on source and the recorded evidence; it did not independently operate a browser.

## Remaining limits

Physical iPhone/Android use, Safari, audio listening quality, long sessions, thermal/memory behavior and human evaluation of fun remain unverified. This version contains one district and one permanent repair objective. Character dialogue, enemy variety and progression are intentionally small; automated checks do not establish the requested final production quality. GitHub CI and the draft PR are tracked on [Issue #211](https://github.com/hayatok/100challenge/issues/211).
