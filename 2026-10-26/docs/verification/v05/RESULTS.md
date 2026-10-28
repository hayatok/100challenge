# SHIOGAERI v0.5 UI checkpoint

Recorded 2026-10-29 JST, as a local UI checkpoint before its commit and CI. This records the harbor/preparation/result work, not completion or publication of v0.5. The committed development baseline is v0.4 at `ebabd8f58a345f91c0c41b6f5901ab328c0a47ea`; its CI run 40730747738 passed. Public remains v0.3 at `e1a83a7`. [PR219](https://github.com/hayatok/100challenge/pull/219) remains draft. No merge, release tag or Pages deployment for the v0.4/v0.5 pair is claimed. Runtime and package metadata still say 0.4.0.

## Resulting behavior

The actual Main now uses the authored harbor and result components. Phone harbor keeps the detailed selected-worker portrait, four roster portraits, current mission and an immediately available basic-loadout shortcut. Detailed cargo opens explicitly. Desktop keeps preparation beside the worker and gives BasicLoadout the full footer row; it does not offer a false close toggle for its permanent pane.

Pack/unpack requests use actual owned UIDs through the existing rule handlers. The pane stays open on phones, focus follows the transferred UID, and scroll changes only when required to reveal that item in its new grid. A read-only rebuild preserves the saved reading position. Preparation reading, focus loss and modal overlays pause background presentation. Desktop inventory focus pauses it even without the phone open latch. Menus do not resolve game turns.

Results immediately show the resolved receipt's actual items, count, value, turn and loss cause, with a pinned harbor action. The existing arrival/loss actor is presentation only and cannot transfer items or replay rewards. An empty result states that no items were brought back; it does not infer a loan-return history from the empty receipt. The expedition board and the production character family remain 2D. Experimental 3D work is not adopted by this checkpoint.

## Evidence classes and automated checks

| Evidence | Source and scope | Boundary |
| --- | --- | --- |
| Final local `npm run check` | Import, legacy 5328/0, tactical 3907/0, components 1150/0, Main UI/store 771/0, Web export; process exit 0 | Complete package path after all UI corrections. This is local verification, distinct from current-head CI and deployment. |
| Native component/Main captures | Authored scenes and actual Main with rule-resolved QA fixtures | Useful for layout, focus, state and presentation checks; not a human playtest or an exported-Web journey. |
| Actual exported Web operation | Parent agent operating the actual game at localhost:4343 at 390x844, 360x740 and 1280x800 | Routes and reloads below used browser inputs and actual game state; they are agent operation evidence. |
| Astra review | Initial findings were fixed; the follow-up reported no findings | Reviewer evidence is distinct from running tests, browser operation and human acceptance. |

All 26 preexisting Main UI test functions remain (the original 20 plus six v0.4 tests). New coverage includes initial quick-loadout visibility, accessible portrait roster actions, actual UID transfers, a long stash with focused-item visibility, exact read-only scroll restoration, QA save/reload, preparation/modal/focus pause, immediate results, storage failure and corrupt-save cancellation. The post-review cases distinguish a real loan-only empty extraction from an owned-knife departure followed by dropping that knife, and check desktop/phone width round trips. Six actual Main paths cover current and migrated legacy loan-only, owned/drop/empty and owned nonempty receipts, including the real Continue action and visible factual harbor feedback while preserving the raw Rules response. These cases derive ownership and receipts from Rules rather than changing a receipt to make the display pass.

The normal test runner includes the presentation suite once alongside legacy and tactical tests, then the package test command runs Main UI/store. Error output and nonzero process exits still fail the runner. Prior v0.4 evidence remains in [the v0.4 record](../v04/RESULTS.md).

## Actual exported Web operation

The parent operator used the new QA origin localhost:4343. The existing player-game origin localhost:4342 and the public origin were left untouched; player storage was not cleared to make the checkpoint appear correct. This documentation pass inspected the saved screenshots and test/export logs and records the parent's operation notes. It did not independently replay the browser session.

At 390x844, the actual harbor exposed the basic-loadout shortcut before opening preparation. Basic preparation packed five starter items. The focused bomb was unpacked and packed again; focus followed the moved item, Escape returned to the showcase, and reload retained the same five carried items. Exact UID preservation is also covered by the native Main/component regressions.

At 360x740, Isana made a real 16-turn quay journey: a bomb broke the wall at cell (8,12) on turn five, the core and scrap were recovered by turn nine, and an announced enemy charge dealt four HP during the approach. Returning with 20 HP produced a receipt of six actual items worth 103 points. A reload retained the same six items, 103 points and 16 turns. This journey preceded the last feedback-adapter/duplicate-empty-label correction; those changes did not touch the rules, field or nonempty receipt layout.

At 1280x800, the actual harbor displayed nine stored items in its permanent preparation pane and a full-width BasicLoadout without a false close control. Beacon delivery consumed the actual stored core/scrap, awarded 20 G and set restoration 1/4; its completion message reported the next-run sight increase. The delivery did not automatically switch the selected route; choosing the next route remains a manual step.

A loan-only departure immediately extracted at turn zero with an empty receipt. The corrected result text reports only the empty result, and the next action remained available.

The separate owned-knife case packed only an actual stored knife: stash seven to six, one carried item, attack three, with no loan. After departure at turn zero, the inventory Drop action left that knife on the exit tile and resolved one turn. With an empty bag, zero value and 24 HP, extraction produced zero items, zero points and one turn. The receipt's neutral empty text was supported by the actual state. Returning to harbor exposed a further old Rules event string that incorrectly claimed a loan had been returned. Main now derives the visible harbor feedback from the structured extraction count. Current Rules and frozen Legacy remained byte-for-byte unchanged. The result also removes the duplicate empty explanation, leaving one factual message.

After the final complete check/export, Kohaku took four owned basic items plus the automatic loan knife: five carried items worth 49 points. Four moves north and deliberate waits next to the crab caused an actual death on turn 28. The result immediately listed medicine, bomb, flare, coat and loan knife with values 8, 14, 9, 18 and zero, and the rust-crab attack as the cause. Reload/Continue retained the same character, five items, 49 points, 28 turns and restoration 1/4. This was an intentional loss test, not a human enjoyment test.

Back in harbor, BasicLoadout packed the two surviving stored items, medicine and flare. A new departure added the loan knife, so the actual retry had three carried entries worth 17 points. Immediate extraction returned the two owned items at turn zero; the actual result showed two items and 17 points. The corrected harbor feedback stated the confirmed two-item count. A further loan-only departure and empty extraction on the final build showed one neutral empty explanation and a neutral harbor message. The exchange screen still showed 20 G; no purchase or sale was performed. Another reload and preparation-panel operation showed zero carried items, two stored items and the repaired-lamp control. These operations used normal game inputs and reloads, without changing browser storage or injecting a result.

Captured warning/error entries after the final journeys were empty. The final 360x740 DOM/canvas bounds matched at device-pixel ratio one. These logs and screenshots establish the operated desktop browser environment; they do not substitute for physical phones or Safari.

Selected evidence:

| Artifact | What it establishes |
| --- | --- |
| [Phone preparation](web-preparation-390.png), [desktop harbor](web-harbor-desktop.png) | Actual Web layouts; capture revisions are identified in the manifest. |
| [First real return](web-first-return-360.png), [beacon completion](web-beacon-completed-desktop.png) | Six-item/103-point journey and the subsequent delivery. |
| [Final-build loss](web-loss-360.png), [reloaded loss](web-loss-reloaded-360.png) | Five-item/49-point/28-turn loss retained after reload. |
| [Retry return](web-retry-return-360.png), [empty return](web-empty-result-360.png) | Two owned items retained through retry; one factual empty explanation. |
| [Positive feedback](web-positive-feedback-360.png), [empty feedback](web-empty-feedback-360.png) | Corrected structured extraction messages on the final build. |
| [Retained warehouse](web-retained-stash-360.png), [retained credits](web-retained-credits-360.png) | Two stored items and 20 G after loss/retry/reloads. |
| [Owned-empty native result](native-owned-empty-result.png), [native harbor](native-owned-empty-harbor.png) | Final real-Main rules-derived fixtures, explicitly native evidence. |
| [Check transcript](check-output.txt), [artifact manifest](artifact-manifest.json) | Full local package path, source/artifact hashes and source-rule preservation. |
| [Japanese review manifest](japanese-review.json), [verify output lines](japanese-verify.txt) | Eleven current final-file hashes matched direct CLI review records. |

## Review corrections and Japanese text

The mandatory `ai_slop_reviewer` / `gpt-6-astra` initially identified two P3 issues: claiming a returned loan for every empty extraction, and offering a desktop preparation toggle that could not hide the permanent pane. Rendering now states only supported empty-result information; the desktop toggles are hidden, while its preparation pane and basic-loadout shortcut remain usable. Rules-derived regression cases cover both. The focused follow-up reported no findings. Subsequent Web operation found the additional old event-string claim described above; the new Main adapter and six current/legacy regressions address it without changing either rules source. Submit the final adapter, evidence and documentation together for the parent's final Astra review, and record that outcome with the PR checkpoint. Reviewer inspection is distinct from independent browser operation.

Changed Japanese-bearing UI/Main/test sources, README and VERSION_PLAN have direct CLI lint/run/verify records with retained originals and exact final hashes. Code colons, identifiers, intentional layout dimensions and fixture seeds are retained where they match their implementation. Candidate counts are not readability or correctness scores. The selected Japanese-review manifest identifies the verified records and hashes.

## Remaining gates

v0.5 remains incomplete. The 3D source/derived mesh, cloud rig and exported clips are under pose, texture/UV and normalization comparison; source or export existence does not pass an animation or adoption gate. Real gait cycles exist, but normal one-cell stops failed the current foot-grounding gate. The four-worker family, production environment/staging and actual-scale motion gates remain open. The detailed comparison and provenance belong to [V05_PRESENTATION.md](../../V05_PRESENTATION.md) and its referenced records; this UI checkpoint does not certify them.

Two Sol execution workers became unavailable with model-capacity errors after saving their work. The parent finished this evidence/documentation record from the saved drafts; a separate Astra execution worker handles the bounded grounding experiment. That handoff does not replace the mandatory independent Astra review.

Physical iPhone/Android, Safari, audio listening, long sessions, human first-play enjoyment and commercial acceptance remain unverified. The current maps are authored and repeatable, and cleared return routes can be quiet. Tests, generated assets, native fixtures and agent-operated routes do not establish fun or commercial quality.

Current-head combined CI, completion of the remaining v0.5 gates, reviewed merge, the paired Pages tag and public/same-run Linux-artifact verification are still required at the publication boundary. No new public version is claimed here.
