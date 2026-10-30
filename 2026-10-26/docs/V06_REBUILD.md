# v0.6: an expedition worth risking

Goal: choose what to bring home, then decide whether the current equipment and health justify another sector. The user reopened development on 2026-10-30 after playing v0.5, citing unnatural inventory operation, weak quest purpose and monotonous stages. This is one substantial version, tracked in Issue #220. Held 3D prototypes remain held.

Context: the active v0.5 generator has fixed collision geometry, caches and enemies; seed affects decoration. Its automatic looting and first-packed equipment selection hide choices. Its quay's nine loot items plus five basic items exactly fit Isana's fourteen slots. Existing UI polish cannot solve these structural problems.

Constraints: Godot 4.7.2, existing sunlit 2D art family, deliberate turns, all carried/equipped items lost on death, stash and completed jobs survive. Reading, sorting, viewing loot and confirmations cannot advance time. Extraction transfers ownership once. Preserve original saves before migration and keep existing expeditions under their original rules. No new dependency, provider spending, automation or 3D adoption.

## Rebuild

1. Generate district-specific rooms and connections in a 25 by 29 grid. Eight variable rooms, a connected dry backbone and loops make different seeds change the route, not just decoration. Low shortcuts and optional breach walls support existing tools. Place supplies, goal, equipment and guards according to room roles. Guarantee a safe landing and reachable dry return, goal and onward route. Store the full generated map in the resolved save.
2. Each departure can visit three sectors. A marked passage advances to a newly generated sector while preserving HP, equipment, items, crew uses and total turns. Advancing costs a turn. Previously abandoned ground items cannot be retrieved. Every sector has a landing for extraction. Story components appear in the first sector; deeper equipment and mixed components make pressing on optional.
3. Inspect an adjacent unopened cache for one turn. Reading an already opened cache is free. Choose a particular item, take what fits, or exchange one carried item for one cache item in a single turn. Overflow stays in the cache. Show item purpose, equipment comparison, contract relevance and exact action cost. Keep the reading context open after actions when the player survives.
4. Preparation has explicit weapon and armor UID references. Carrying a second weapon does not silently equip it. Harbor equipment changes cost no turn; expedition equipment changes cost one. Provide one action to return the entire loadout to the stash. The visual equipment slots reference the same carried items, never extra ownership.
5. Keep all eight existing job completions and rewards. Explain who needs the goods, where they are found and what changes after delivery. Personal jobs unlock actual supply discounts or map knowledge. Repeat salvage orders provide another destination and real equipment/supply rewards after the lighthouse is repaired. No daily appointment, XP treadmill or passive income.

## Evaluation

Hypothesis: a newly found tool or quest component changes which cache to leave behind, whether to use a scarce item in combat and whether to descend. If a player can still collect everything without choosing, the loot/capacity balance has failed. If another seed leads to the same path and decisions, generation has failed. These are design hypotheses, not established human enjoyment.

Done when: seed sweeps verify connectivity, real collision-topology diversity and deterministic replay; old saves and future old-run actions match; selected loot, full-bag exchange, depth advance, death, extraction, delivery and repeating orders conserve UIDs and round-trip through storage. Operate the exported game at 390x844, 360x740 and desktop, including a normal expedition. Record mistaken inputs and limits honestly. Complete Japanese run/verify, mandatory Astra review and current-head CI. Tests alone cannot establish fun or commercial quality.

This version completes locally and through a reviewed PR. The previous two-version Pages cadence remains; this single version does not automatically trigger a release or reopen indefinite iteration.

Design references consulted: [Shiren 6 official guide](https://www.spike-chunsoft.co.jp/pages/shiren6/guide/) and [official systems](https://www.spike-chunsoft.co.jp/pages/shiren6/system/). Their descriptions support considering turns, resource decisions and changing explorations; they are not playtest evidence for SHIOGAERI.
