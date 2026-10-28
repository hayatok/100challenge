# SHIOGAERI continuous development

## Goal, context and authorization

The user requested continuing development until explicitly stopped, with GitHub Pages publication after every two completed versions (2026-10-28 JST). The previous presentation revision at `5624789` is baseline v0.1, not a finished commercial game. Preserve that work, unrelated checkouts and all existing player progress. Use this document as the version ledger across resumptions; inspect GitHub Issue #211 and its Project before creating duplicate work.

The desired loop is: choose a meaningful job and region, commit a loadout, discover routes and loot, decide what to risk, return real items, improve the harbor or a companion's circumstances, then choose a different expedition. Death still loses all carried items and equipment; stored items and completed town/character progress remain. Add choices and encounters, not a compulsory resource treadmill or inflated combat statistics.

Latest steering on 2026-10-29 JST: resume continuing development until stopped, with substantial redesign of play, graphics, staging and HUD toward commercial quality. The user explicitly rejects minor fixes as the main work. This supersedes the 2026-10-28 pause after the verified v0.3 publication. See V04_REBUILD.md and V04_ART_BRIEF.md. Work in versions, preserve saves and evaluate actual operation at each checkpoint. A thread heartbeat was created and its view succeeded for continuity; it must honor any later stop instruction.

## Publication cadence

Count completed versions since the latest verified Pages publication, rather than relying on odd/even version numbers. The first pair is v0.2 + v0.3. Then v0.4 + v0.5, and so on. A version is complete only after its implementation, relevant tests, actual screen/operation checks, Japanese review and mandatory Astra review. At each pair boundary: update the PR, require passing current-head CI, merge the reviewed change, tag the exact intended main commit through the existing Pages route, verify the deployed Linux artifact/public files and gameplay, record the URL and version, then begin the next pair. Deployment success alone is not human acceptance of fun or commercial quality.

The renewed continuation request restores the established cadence after v0.3: publish each two completed versions through reviewed PRs and the existing Pages route. Preserve a recoverable history and save migrations; never reset player storage to make a new version appear correct. The previous absent/deleted automation and pause remain historical records, not the current instruction.

## v0.2 — routes, reconstruction and companion jobs (complete)

Goal: replace the single-map, single-repair dead end with a complete campaign and a useful salvage economy. Context: pure rules/world generators, strict version1 save validation, existing four workers, turn/save invariants and the Sunlit Tideglass presentation. Constraints: Godot4.7.2, single-thread Compatibility Web, no new runtime dependency, no automatic turn progression, no automatic receipt duplication or meta progress from lost loot.

- Four districts with genuinely different traversal and encounter layouts: the existing low-tide quay/lighthouse, an enclosed market with courtyards and flanking alleys, a canal with islands/bridges and risky flooded shortcuts, and a cliff observatory with a ring approach and a guarded final cache. Keep25x25 and exit(12,23) for the initial implementation, but change the routes, walls, water and loot branches. Seeded variation must preserve objective reachability and at least one dry return path.
- Four reconstruction contracts form the story: lighthouse core+scrap restores the beacon and opens the market; market pump gear+scrap opens the canal; canal chart+pearls opens the observatory; observatory sun lens+gear restores the harbor network. The requirements/rewards and next destination must be visible. Claim only from actually stored items, once. Keep the old repair action as an alias for the first reconstruction, including old-save progress.
- Four companion contracts, one per worker, give distinct personal motives, real deliveries and equipment/credit rewards. Characters have stage-dependent conversations tied to completed jobs and the selected destination; do not promise branching consequences that are not implemented. More companion chapters follow in later versions.
- Harbor exchange: sell actual stored items for credits, buy basic supplies at recorded prices. Credits stay in the harbor; equipped/carried items remain at risk. A free loan knife and nearby recoverable supply cache prevent an unrecoverable equipment lock. No idle income, premium currency or monetization.
- Campaign UI: a concise current job, route selection with lock reasons, job details with actual required/owned items, companion dialogue and exchange with real prices. Keep loading/error/empty/ready/claimed states, safe areas, keyboard focus and52-logical-pixel primary controls. Menus do not cost turns.
- Migrate strictly validated version1 harbor/result/in-progress expedition saves into a version2 schema. Keep the same storage key and positions, turn, HP, equipment, loot and receipt. Never accept malformed saves merely to migrate them. New districts and campaign progress must round-trip through JSON.

Done when: an automated rules route and an actual exported-game route cover first completion, unlocking/selecting another district, delivery, exchange, save/reload and a death that preserves town progress but loses the actual carried items. Inspect all4 district layouts and map/objective/exit connectivity across seeds. No estimated play length is to be reported as measured human playtime.

## v0.3 — living crew and region presentation (complete; release checkpoint)

Goal: make characters and places visibly move and read as a cohesive adventure. Work may be prepared in parallel with v0.2, but it counts as a separate completed version only after independent integration and checks.

- Character motion must show facing, a real alternating stride/foot plant, arm/weapon anticipation and recovery, recoil and distinct idle/arrival/loss behavior. Avoid a rigid cutout merely sliding or bobbing. Keep UI responsive, deliberate inputs exact, outcomes readable and reduced-motion/focus/modal pause correct.
- Give the4 districts different palette, water treatment, architecture, props and landmark composition. Place props from the current district's actual map/anchors; do not paint an unrelated fixed town over different collision geometry. Preserve fog knowledge, exits and enemy telegraphs.
- Build any additional image assets only after a per-version art/animation brief, using built-in GPT generation or an explicitly documented suitable tool. Inspect actual silhouettes, face identity, frame alignment, alpha and in-game scale. Keep originals and provenance. All four women remain adults with their established identities.
- Crew interactions and campaign milestones receive contextual portraits/gestures and short readable staging. Do not obscure the next action, force long delays or turn every ordinary move into a celebration.

Done when: actual native/Web motion sequences at phone sizes show the above actions and all districts; pure state, input, pause and save tests remain correct; Japanese and Astra reviews complete. Publish v0.2+v0.3 as the first pair and verify the public game.

## Current pair: v0.4 and v0.5

v0.4 rebuilds expeditions with compact encounters, worker techniques, truthful action previews, strict legacy-run migration, a much larger playable field and a new HUD. Its development checkpoint is committed at ebabd8f, with CI40730747738 passed. v0.5 is still in progress: the harbor/preparation/result UI is a reviewed checkpoint, while the character animation method, four-worker family and environment adoption gates remain open. Both versions must be assessed through actual operation. Later pairs follow concrete observed weaknesses; do not automatically implement a feature count as proof of quality.

### v0.5 UI checkpoint, not version completion

The actual Main now uses authored harbor and result scenes. The phone harbor preserves the detailed selected portrait and an immediately available basic-loadout shortcut; detailed cargo opens explicitly. Desktop keeps its preparation pane beside the worker, without a false close toggle. Exact UID transfers retain the open reading context, focus follows the item to its new location, and a read-only rebuild preserves the saved scroll. Reading preparation, modal overlays and focus loss pause presentation. Result count, value and actual receipt items are available immediately; animation cannot transfer ownership or delay the next action.

Mandatory Astra review identified an unsupported claim about returning a loan on every empty extraction and a desktop toggle that could not close its permanent pane. Both were corrected; the follow-up reported no findings. Subsequent actual Web operation found an unchanged raw Rules loan-return message leaking into Harbor feedback after an owned-knife/drop/empty extraction. A narrow Main adapter now derives that visible feedback from the structured extraction count, while Rules/Legacy remain byte-for-byte unchanged. The adapter revision and this documentation are included in the parent's next follow-up review. The final complete `npm run check` passed import, 5328 legacy, 3907 tactical, 1150 component and 771 Main UI/store checks, plus Web export, with process exit zero. Actual exported Web operation and evidence boundaries are recorded in [verification/v05/RESULTS.md](verification/v05/RESULTS.md).

This does not complete v0.5 or authorize describing the experimental3D character as production art. Source/runtime package metadata remains0.4.0. Public remainsv0.3 at e1a83a7, PR219 remains draft, and no merge, tag or Pages publication for this pair has occurred. The established publication cadence resumes only after the remaining version gates and reviewed current-head CI are complete. Keep the detailed3D comparison and provenance in V05_PRESENTATION.md and its referenced records.

## Ledger

| Version | Status | Gameplay/visual evidence | Publication |
| --- | --- | --- | --- |
|0.1|Baseline at5624789|One district, presentation R2; see its verification record|Not published for this app|
|0.2|Complete at c750371|Campaign/maps/exchange;5328 rules +208 UI/store; actual Web extractions/deliveries/trade/death; Astra review; CI40545309242 passed|Paired with0.3; release outcome in Issue214|
|0.3|Published baseline|Directional crew/portraits/terrain; receipt motion;5328 rules +469 UI/store; actual Web; Japanese/Astra review|Verified release-2026-10-28-2 at e1a83a7; Pages40562758716; Issue214|
|0.4|Committed development checkpoint at ebabd8f; CI40730747738 passed|Compact encounters, techniques, HUD/world rebuild;5328 legacy+3907 tactical+643 UI/store; actual Web return/unlock/deep salvage/loss/retry/legacy continuation; Japanese/Astra review; see verification/v04/RESULTS.md|Pair with0.5 before Pages|
|0.5|Reviewed UI checkpoint; version incomplete|Harbor/preparation/results integrated; complete local check and Web export passed; actual Web return/reload/delivery/loss/retry; 3D method/family/environment not adopted; see verification/v05/RESULTS.md|PR219 draft; no merge/tag/Pages; runtime still0.4.0|
