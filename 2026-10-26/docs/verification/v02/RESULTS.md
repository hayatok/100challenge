# SHIOGAERI v0.2 verification

Development milestone dated2026-10-28 JST, based on5624789. This is the first completed-version candidate in the user's first two-version Pages pair. v0.3 motion/art preparation is outside the imported game in ignored scratch; it is not counted as implemented v0.2 content. No Pages deployment is claimed here.

## Changes

Four districts have distinct routes, water, walls, caches, enemy placements, palette and map-bound landmarks: quay/lighthouse, courtyard market, island canal and cliff observatory. Four reconstruction deliveries advance harbor restoration; the first three unlock the next district. Four companion deliveries grant actual equipment/credits and change dialogue. The harbor includes real route/lock states, a job log, companion conversation and item exchange. Job tracking chooses its district; loot must reach the stash before delivery. Requirements consume concrete stash UIDs once. Credits buy supplies; a loan knife and nearby supply caches keep recovery possible after loss.

The version2 state strictly validates campaign flags, routes, ownership, item registry, credits and existing run invariants. Valid version1 harbor/results/in-flight saves are migrated without changing the resolved turn, HP, equipment, world or receipt. The exact old raw save is retained before the first version2 overwrite; backup failure leaves the original progress untouched and produces a visible error. Storage keys/origins remain compatible. Existing player runs at4316 and4327 were observed/preserved; all browser actions for this milestone use new4331 origins.

## Automated and native checks

- Import,5,328 rules assertions,208 UI/store assertions and single-thread Web export passed together; see[check output](check-output.txt). The final UI suite includes the immediate-overlay visibility regression, with QA disabled only for pure screen construction and restored before any action or persistence. Root tests passed38/38.
- The original1,794 rule cases remain; the unsupported future-save test now uses version3 because version2 is supported. New cases cover deliveries, equipment ownership, credit limits, immutable invalid actions, all districts across32 seeds, dry return/objective/cache connectivity, and full campaign completion on seeds7/42/1234 using only initial equipment and actual recovery/sales/purchases. Every resolved campaign-route turn round-trips through JSON.
- Strict legacy migration includes harbor, successful/failed receipts and late expeditions with intent/loot state. Native backup tests compare the exact original raw string and exercise backup failure/retry in isolated QA paths.
- UI checks use real button signals and valid states for route IDs, locked controls, job follow/delivery, duplicate UID sale/cancel/purchase, both phone sizes, focus/scroll reachability, companion state and storage. Resource-injected UI fixtures are explicitly not playthroughs.
- Region diagnostics passed120 assertions, plus the existing motion/fog/input probe: state invariance, same-seed district changes, authored blocked anchors, hidden enemy/loot protection, camera foot focus, water distinction and overlay freeze/resume. Native sources and logs remain in ignored`.scratch/versions/v02/`.
- Scene/resource checker:114 files,0errors/0warnings.

An early redundant UI process read a test list while its worker was still writing the new function and stalled on a missing method. Only that isolated headless process was stopped. The final combined check above ran after edits settled; do not count the earlier run as successful.

## Actual exported Web operation

The initial127.0.0.1:4331 embedded view stayed280x607 despite viewport requests. A direct tab at the preview server's printed localhost:4331 URL accepted390x844 (read-only DOM measurement). Existing native captures separately cover390x844,360x740 and1280x900. Native rendering and authored/omniscient map fixtures are labelled; they are not browser or human playtests.

A fresh Ritsu run used the real five-item basic loadout, searched the supply cache, fought waders/guard, recovered the lighthouse core and returned on turn73 with HP27/28. One medicine was used. Eight surviving items worth141pt transferred to the stash. Delivering core+scrap completed the beacon, awarded20G and opened the market. Reload preserved the completed reconstruction, selected market, stored items and credits.

Two actually stored medicines were then delivered for Ritsu's personal rescue-shelf job, awarding18G and a flare. The next reconstruction was accepted; buying medicine spent10G from the actual38G balance. The exchange warned that the pearl was required by unfinished jobs before selling it. Selling the actual pearl granted24G (28→52), buying a42G harpoon left10G, and a second medicine purchase left0G. Reopening the exchange after that purchase retained a visible harbor beneath the overlay on the fixed build.

The equipped purchased harpoon and a five-item basic kit were taken into the market. Its central low route gave a shorter approach; the pump cache filled the12-slot bag with two gears and two scraps alongside the supply loot. A medicine was used and the player returned on turn47, HP18/28, with11 items worth167pt. Delivering one gear and two scraps awarded24G and opened the canal. The remaining gear stayed in the stash.

The canal job was accepted and the player carried six items, including the purchased harpoon, onto a low shortcut. At turn32 the causeway flooded and the HUD showed the one-HP-per-turn consequence. Deliberately staying there caused death on turn59 and lost all six carried items (93pt). Returning to harbor retained reconstruction2/4, the completed Ritsu job,24G and six stored items. At360x740 the harbor and completed companion conversation remained readable; at390x844 keyboard focus also scrolled the selected job and shop item into view. At1280x900 the harbor switched to its side-by-side layout; the final direct-browser error log was empty. These actions were in the new QA origin, not the preserved player runs.

Screens include[required items](web-jobs-phone.jpg),[core recovery](web-core-phone.jpg),[eight-item return](web-return-phone.jpg),[beacon completion](web-beacon-completed.jpg),[market selection](web-market-unlocked.jpg),[companion delivery](web-companion-completed.jpg) and[quest-item sale warning](web-sale-warning.jpg). The first completed-job capture predates the final job-order and completed-count wording refinements; later deliveries and the exchange were operated on the fixed build.

Native UI fixtures:[harbor](native-harbor-phone.png),[routes](native-routes-phone.png),[jobs](native-jobs-phone.png),[exchange](native-exchange-phone.png),[crew](native-crew-phone.png),[small harbor](native-harbor-small.png),[small jobs](native-jobs-small.png),[wide harbor](native-harbor-wide.png). The[market](market-map-fixture.png),[canal](canal-map-fixture.png) and[observatory](observatory-map-fixture.png) composition images deliberately expose the whole map for layout inspection; normal gameplay fog remains enforced.

## Presentation fixes found during operation

Completed jobs now say their items were delivered instead of showing zero owned after consumption. Tracked/ready/available jobs precede completed jobs. Confirmation panels have room for both the main and back actions. Currency feedback uses the same G unit as the exchange.

An immediate reopened overlay could pause the freshly rebuilt harbor's entry fade at alpha0. Opening an overlay now finishes only the background screen-entry fade before freezing presentation, retaining a visible harbor underneath. The latest Web purchase/reopened exchange and the dedicated visibility/state regression both passed; see[fixed overlay](web-exchange-overlay-fixed.jpg).

## Review and remaining limits

Seven Japanese-bearing files were read against the implementation, with direct Bash CLI yomiyasu run/verify hashes matching the final files; see[japanese record](japanese-review.json). README now distinguishes reconstruction route unlocks from companion rewards. Necessary GDScript colons and clear save instructions were retained; counts/hashes are not quality scores. The final ai_slop_reviewer / gpt-6-astra follow-up found one low-severity documentation ambiguity: the final reconstruction completes restoration rather than opening a fifth district. That sentence is corrected above; no code findings remained. The reviewer inspected code, logs, saved images and Japanese hashes, and did not independently operate the browser. Current-head CI is pending before version closeout. The user authorized publication after v0.2+v0.3; v0.2 alone is not a publication checkpoint. Human first-play acceptance, physical phones, Safari, audio listening, long sessions and commercial release readiness remain unverified. No measured play-length or fun claim follows from the added content count or assertion count.
