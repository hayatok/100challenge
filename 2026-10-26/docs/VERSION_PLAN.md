# SHIOGAERI continuous development

## Goal, context and authorization

The user requested continuing development until explicitly stopped, with GitHub Pages publication after every two completed versions (2026-10-28 JST). The previous presentation revision at `5624789` is baseline v0.1, not a finished commercial game. Preserve that work, unrelated checkouts and all existing player progress. Use this document as the version ledger across resumptions; inspect GitHub Issue #211 and its Project before creating duplicate work.

The desired loop is: choose a meaningful job and region, commit a loadout, discover routes and loot, decide what to risk, return real items, improve the harbor or a companion's circumstances, then choose a different expedition. Death still loses all carried items and equipment; stored items and completed town/character progress remain. Add choices and encounters, not a compulsory resource treadmill or inflated combat statistics.

Latest steering on2026-10-28 JST: finish the current v0.3, publish the first pair, verify the public build, then stop development. Do not begin v0.4 or schedule further continuation. Do not create or resume automatic follow-ups at that checkpoint. The later-pair proposals below are retained as future ideas, not authorized active work after this stop.

## Publication cadence

Count completed versions since the latest verified Pages publication, rather than relying on odd/even version numbers. The first pair is v0.2 + v0.3. Then v0.4 + v0.5, and so on. A version is complete only after its implementation, relevant tests, actual screen/operation checks, Japanese review and mandatory Astra review. At each pair boundary: update the PR, require passing current-head CI, merge the reviewed change, tag the exact intended main commit through the existing Pages route, verify the deployed Linux artifact/public files and gameplay, record the URL and version, then begin the next pair. Deployment success alone is not human acceptance of fun or commercial quality.

No extra permission is required for the first pair's publication. The latest stop request takes precedence over the original repeating cycle. Preserve a recoverable history and save migrations; never reset player storage to make a new version appear correct. The proposed heartbeat was reported absent by the app and no active goal was returned; do not create a replacement or restart development after this checkpoint.

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

## Next pair candidates

v0.4: expedition modifiers, encounter variants and equipment choices that change tactics; replay contracts after the main reconstruction. v0.5: more companion chapters, distinctive enemy/boss behavior and authored encounter/motion polish. Refine this pair after playing the previous one; do not automatically implement a feature count as proof of quality.

## Ledger

| Version | Status | Gameplay/visual evidence | Publication |
| --- | --- | --- | --- |
|0.1|Baseline at5624789|One district, presentation R2; see its verification record|Not published for this app|
|0.2|Complete at c750371|Campaign/maps/exchange;5328 rules +208 UI/store; actual Web extractions/deliveries/trade/death; Astra review; CI40545309242 passed|Paired with0.3; release outcome in Issue214|
|0.3|Complete; release checkpoint|Directional crew/portraits/terrain; receipt motion;5328 rules +469 UI/store; actual Web; Japanese/Astra review|Publish pair, verify public game, then stop. Exact SHA/tag/outcome in Issue214|
