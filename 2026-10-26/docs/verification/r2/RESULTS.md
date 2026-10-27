# SHIOGAERI presentation revision 2

Work dated 2026-10-28 JST. Baseline `d240b3a`; the worktree started clean. This is a local presentation revision, with the existing one-district game loop. No deployment, release tag or merge is included.

## Visible changes

The new Sunlit Tideglass family uses a bright harbor, turquoise sea, warm stone, white/coral masonry and honey timber. Four field miniatures retain the adult crew's identities. Buildings and boats are larger landmarks; clearance fades preserve the player, loot and charge warning. Unseen enemies and loot stay hidden.

Title, harbor, HUD, inventory, settings and results share nautical paper/enamel framing, dark ink, amber primary actions, portrait crops, original illustrated item icons, compass ornaments and clear keyboard focus. The HUD reports actual HP, carrying capacity, tide, objective and carried value. Inventory selection operates on the real UID; full-health healing is visibly unavailable. Small inventories use a shorter panel.

Walking has a stride and planted feet. Combat has anticipation, a slash, contact flash, damage figures and particles. Loot has rising symbols; tide has a sweep; successful return has item reveals, a real value count-up and brief confetti. Large camera travel and loops stop with reduced motion. Menus and application focus pause presentation and sound without advancing rules.

Original music uses four phase-aligned layers at 96 BPM in D major, with a sea bed and varied footsteps. Event priority, an eight-voice pool, ducking and scene fades control overlap. Audio remains unassessed by human listening.

## Actual Web interaction

The exported game was operated with pointer and keyboard in the Codex in-app browser on a separate QA origin, `http://127.0.0.1:4327/`. Existing player progress at port 4316 was not modified.

The browser's viewport override was ineffective: the outer panel remained 280 x 607. Temporary ignored `dist/qa-*.html` harnesses embedded the actual game in 390 x 844, 360 x 740 and 1280 x 900 CSS-pixel iframes, with a CSS transform to fit the panel. Read-only DOM measurements confirmed each inner window's size. These are browser layout/interaction checks in a scaled preview, not physical-device touch tests. Screenshot APIs also returned only the outer panel, so full-resolution presentation images below are explicitly native fixtures.

A Ritsu run packed a knife, raincoat and medicine, recovered the supply crate, fought waders, reached the lighthouse, recovered its core and pearl, used one medicine, and returned on turn 73 with HP 27/28. Six surviving items transferred to the stash once. The counter settled at 118 pt. Reload at turn 4 restored HP 28/28 and five carried items. Reading the inventory and pressing movement inside it left the turn at 4. The medicine panel showed the full-health reason, then later allowed actual healing after damage.

The return screen showed its real receipt, then the harbor showed 11 stored items. Repair consumed the core and scrap, leaving nine. An Isana run packed five items and was lost to a wader charge on turn 33; the receipt listed the five lost items, including knife and coat. The harbor retained four stored items. An empty loadout then received a loan knife and departed. Settings, reduced motion, small-screen bag and desktop expedition controls were also operated. On the final build, a one-item bag used the compact panel; immediate return excluded the loan knife, showed a zero-item/zero-value receipt and retained the repaired harbor objective.

The browser log contained two unattributed `MutationObserver.observe` TypeErrors at harness navigation. `MutationObserver` does not occur in the game or exported script sources; the origin of that browser message is unconfirmed. No Godot script error was observed during the recorded run. Do not describe the browser console as completely error-free.

| Evidence | Interpretation |
| --- | --- |
| [Before expedition](before-expedition.jpg) | Original embedded browser view, 280 x 607; not a same-size phone comparison. |
| [Web expedition](web-expedition-phone-scaled.jpg), [bag](web-inventory-phone-scaled.jpg) | Actual 390 x 844 game inside the scaled browser harness. |
| [Web lighthouse](web-lighthouse-phone-scaled.jpg), [return](web-return-phone-scaled.jpg), [loss](web-loss-phone-scaled.jpg), [empty return](web-empty-return-phone-scaled.jpg) | Actual play, not injected game-state fixtures. |
| [Web small](web-expedition-small-scaled.jpg), [wide](web-expedition-desktop-scaled.jpg) | Actual smaller/wider inner CSS layouts shown at reduced outer-panel size. |
| [Native title](native-title-phone.png), [harbor](native-harbor-phone.png), [field](native-expedition-phone.png), [inventory](native-inventory-phone.png), [result](native-result-phone.png), [loss](native-loss-phone.png) | Full-resolution 390 x 844 rendered fixtures with isolated QA state. |
| [Native small bag](native-inventory-small.png), [small field](native-expedition-small.png), [wide harbor](native-harbor-desktop.png), [wide field](native-expedition-desktop.png) | Full-resolution 360 x 740 and 1280 x 900 layout fixtures. |
| [Native safe area](native-safe-harbor-phone.png), [settings](native-settings-phone.png), [map](native-map-phone.png) | Scripted insets 44 top/34 bottom, modal and supporting-screen inspection. |

Native fixtures call the real rules to prepare states, then render actual scenes. They are not human playtests or generated mockups. The capture harness and world/action diagnostics remain in ignored `.scratch/quality-r2/`.

## Checks

- Godot 4.7.2 import and single-thread Compatibility Web export succeeded; [check output](check-output.txt).
- Rule assertions: 1,794 passed. UI/store assertions: 92 passed, 58 more than the baseline; zero failed; [final test output](final-test-output.txt).
- New integration checks exercise actual button signals for duplicate-item UID selection, use, directional use and dropping; full-health disabled state; readable empty receipts and their real return action; Tab/Shift-Tab navigation within the modal; 390/360 layouts and CSS-sized targets; overlay ordering; modal/focus/reduced-motion pause and state invariance.
- Root `npm test`: 38 passed.
- Scene/resource checker: 107 files, zero errors and warnings.
- Development world runtime checks: zero failures for rules-state invariance, enemy/loot visibility, landmark anchor/clearance, foot focal ratio, pause/resume and input. Audio lifecycle diagnostics: 48 passed using the Dummy driver, including loops, voice limits, mute, focus and teardown. These diagnostics do not replace Web or audio listening evidence.

Verification exposed an empty-receipt message shrinking to one character per line inside a multi-column grid. Empty results now use one expanding column. The real Web zero-item return and new small/phone regression assertions cover this case.

The native captures use window sizes 390 x 844, 360 x 740 and 1280 x 900. Godot's stretch mapping uses logical 410 x 844 at the small size and 1200 x 844 at desktop. A 52-logical-pixel button is about 45.7 CSS pixels tall at the small target. The nonzero safe-area fixture clears its top and bottom insets. Physical notch behavior is not confirmed.

## Assets and design process

The direction was written in [PRESENTATION_R2.md](../../PRESENTATION_R2.md) before R2 generation. Skills used for this revision include game-quality-design, game-design, create-game-assets, game-feel, game-ui-ux, Godot UI/animation/scene work, camera systems and audio design. No new runtime library was added.

Five built-in GPT image generation calls produced the harbor, terrain, props and crew family. Original sheets are preserved. The crew slicer extracts disjoint alpha components without repainting visible pixels; native resources and the manifest record inspected regions. Original UI SVGs and synthesized audio include their source files and provenance. Existing portraits, world rules and save validation remain intact.

## Review and limits

Changed Japanese UI strings, loading copy and README were compared with the implementation and inspected with yomiyasu. CLI `run` and `verify` matched the three actual files; [record](japanese-review.json). GDScript colons remain syntax, and the clear repeated save instructions remain. Candidate counts are not quality scores. Originals and full records remain in the ignored scratch directory.

The mandatory read-only reviewer `ai_slop_reviewer` (`gpt-6-astra`) reported no findings after reading the R2 sources, new assets/resources/tests, specifications and saved screen evidence. It did not independently run the game, operate a browser or listen to audio. Its follow-up also reported no findings after checking the empty-result layout fix, regression coverage, Japanese hashes and final verification evidence.

Physical iPhone/Android, Safari, human audio listening, long sessions, thermal/memory profiling, human evaluation of the first five minutes, and a broader balance/content pass remain unverified. This revision materially changes the presentation; it does not establish commercial release readiness or add districts, enemies, progression systems or character storylines.
