# Implementation contract

## Current v0.6 / schema 4

`rules.gd` is the public facade. `rules_v05.gd` freezes the shipped schema3 implementation (only its class name changes); `legacy_v03_rules.gd` and `world_data.gd` retain older behavior. `v06_rules.gd`, `v06_world.gd` and `v06_campaign.gd` own new departures. Valid existing in-flight saves remain schema3 and resolve through the frozen engine, including their terminal turn and receipt. Returning from that result adopts schema4. Loading an old harbor/result adopts schema4 immediately. Unsupported/corrupt sources are rejected before normalization.

Schema4 adds root `preparation:{weapon:UID|null,armor:UID|null}` and profile `commissionCycle:integer`. Preparation slots refer to carried UIDs, never extra copies. Pack selects equipment only for an empty slot. Unpacking a selected piece clears its reference. Harbor `equip` and `unpack_all` are free. Departure uses those exact references; if no weapon is carried, the existing free returnable loan is provided. The UI requires explicitly choosing a remaining weapon after unpacking the selected one.

New run `ruleset="expedition-v06"`, width25/height29, adds `depth:1..3`, `stairs:{x,y}`, `layoutName:String`; other ownership, equipment, turn, tide, sight, encounter and landmark fields retain their roles. Each resolved full map is serialized. Seed changes room shapes, connection graph, objective/loot positions and guards. All required points have an elevated route. Hidden containers and enemies remain undisclosed by geometric map knowledge.

- `nearby_containers(state)` returns currently visible adjacent caches, with `{id,x,y,searched,count,name}`; unopened count is−1.
- `container_contents(state,id)` (alias `contents`) returns copied item dictionaries only from an opened, currently visible adjacent cache. Otherwise returns[].
- `interact` at the landing extracts; `interact` with `containerId` inspects one cache for one turn, without moving its items. Reopening is a free read.
- `take {containerId,uid}`, `take_all {containerId}` and `swap {containerId,uid,dropUid}` each cost one turn on success. Swap atomically puts the carried UID in that same cache and takes the chosen cache UID; swapping equipped gear clears its reference. Overflow remains. Invalid, remote or unsearched access spends nothing. Enemy/tide phases run after the inventory transaction; death still loses the resulting carried inventory.
- `advance` is available only standing on stairs at depth1/2. It generates the next sector and advances one turn, preserving HP, items, gear, crew uses, seed and total clock/tide. Survey expires; seen knowledge is rebuilt for the new map. No healing or supply refill. Old-sector ground items cannot be revisited. The next sector has an extraction landing; depth3 is final.

Original story/companion claims, amounts and completed IDs persist. Personal jobs additionally grant real medicine/bomb/flare purchase discounts (never below resale value), or atlas geometry knowledge. `salvage_order` is a repeatable tracked job after beacon completion. Its requirements/reward change by commissionCycle; a claim consumes actual stash UIDs and increments the cycle. It is not inserted into completedContracts. Currency bounds and no-double-consumption apply.

The save key remains `shiogaeri-save-v1`. Before overwriting valid schema3 with schema4, Store retains exact raw source bytes at `shiogaeri-save-v1-pre-v4` or `user://expedition.pre-v4.json` (custom slots get corresponding suffixes). Backup failure blocks the update. Existing pre-v2/pre-v3 protections remain. Rendering, sorting, modal state, focus and animation cannot advance time or transfer items.

## Frozen v0.4-v0.5 / schema 3

The current public facade is `rules.gd`. State version is 3. New departures use `run.ruleset = "encounter-v04"`, a 17x19 authored encounter world, `crewCharges` (0..3), `surveyUntil` (resolved turn), and validated `encounters` and `landmarks` metadata. The delivery cache is in the middle area; optional salvage lies farther in. The four existing campaigns and UID ownership contract remain. The frozen schema 2 description below applies to legacy runs, not to new map dimensions or new actions.

`migrate_state` validates exact old v1/v2 data before copying it to schema 3. Old in-flight runs add only `ruleset = "legacy-v03"`; resolution delegates to frozen `legacy_v03_rules.gd` with all original item, enemy, tool and tide effects. The original `world_data.create_world` generator remains intact. After that run finishes, the next departure uses the new ruleset. The save key stays the same. Before overwriting a valid v1/v2 source, `save_store.gd` retains the exact raw bytes under `shiogaeri-save-v1-pre-v3` on Web or `user://expedition.pre-v3.json` for the normal native slot (or the custom slot path plus `.pre-v3`); backup failure blocks the write. Existing pre-v2 backups remain preserved.

Pure query APIs: `crew_info(state)` returns name, description, charges, maxCharges, targeted and available. `preview_action(state, action)` resolves an isolated deep copy and returns valid, reason, incoming damage, resourceCost `{items, crewCharges}` and destination `{x,y}`. It does not return hidden cargo or mutate state. `threats(state)` returns visible enemyId/kind/cells/text/phase information; the renderer must not duplicate AI/damage rules or draw hidden enemies.

New action `{type:"crew", dx?, dy?}` costs one resolved turn and one of three expedition uses only on success. Isana moves two clear cardinal cells; Ritsu reduces each enemy hit this turn by 3 to a minimum of 0 (not tide damage); Kohaku deals 2, pushes an adjacent foe up to two clear cells and stuns the current and following enemy phases; Sui surveys radius 5 through walls for three resolved turns including activation and retains discovered map knowledge. No-effect/invalid targets spend neither turn nor charge. New actions do not apply to legacy runs. Descriptions and availability come from the rule query.

Presentation metadata uses exact JSON rows: encounters `{id,name,x,y,w,h}` and landmarks `{kind,x,y}` at actual wall/water anchors. Board APIs preserve `present`, `cell_selected` and `get_visible_tiles`, adding `set_playable_rect(Rect2)` and `set_action_preview(Dictionary)`. The field shell places touch controls outside the world and derives risk previews through Rules. All presentation remains unable to advance time or transfer items.

## Frozen v0.3 / schema 2 reference

Engine files: `game/scripts/rules.gd`, `game/scripts/world_data.gd`. No DOM, external dependencies, dates, or browser storage inside the engine. JSON-serializable state. Godot 4.7.2 RefCounted scripts with static methods; load directly with preload.

Exports from rules.gd:
- CHARACTERS: four adult female recovery workers with distinct artwork, dialogue and one explicit trait each. Choose in harbor with {type:choose,character}. Isana capacity14, Ritsu maxHp28, Kohaku melee+1, Sui sight+1; defaults capacity12,maxHp24,sight5. Lamp repair adds sight+1.
- ITEMS: object keyed by kind; each definition has name (Japanese), description, category (`weapon`, `armor`, `consumable`, `material`, `treasure`), icon, value, and optional attack/defense.
- ENEMIES: keyed definitions with name, description, hp, attack.
- new_game(): returns state.
- apply_action(state, action): returns {state, events}; never mutates the input. Invalid actions do not advance turns. Events have type, text, optional x,y,amount,actorId.
- stats(state): returns attack, defense, capacity and any other derived values.
- visible_tiles(run, radius?): Dictionary of `x,y` keys. Update run.seen as an array after resolved actions.
- validate_state(value): boolean; strictly reject malformed or unsupported version2 saves.
- migrate_state(value): returns a normalized version2 state, or an empty Dictionary. First validates a version1 state against the original exact schema (including legacy item kinds); migrates only after validation. Version2 input is also strictly validated. No input mutation.
- current_district(state), campaign_summary(state), contracts(state), dialogue(state, character), shop_rows(state): read-only campaign/UI data, delegated to `campaign_data.gd`. Contract requirements count actual stash contents only.

State: {version:2, character:'isana'|'ritsu'|'kohaku'|'sui', mode:'harbor'|'expedition'|'result', profile:{stash:Item[], runs:number, extracts:number, deaths:number, lampRepaired:boolean, credits:integer, selectedDistrict:string, activeContract:string, completedContracts:string[]}, loadout:Item[], run:null|Run, result:null|Result, nextId:number}.
Item: {uid:string, kind:string}. Unique uid across all places. Equipment is in inventory and takes capacity.
Run: {district:string, seed:number, turn:number, tide:number, player:{x,y,hp,maxHp,facing:{x,y}}, inventory:Item[], weapon:string|null, armor:string|null, tiles:Tile[][], width,height, enemies:Enemy[], containers:Container[], seen:string[], exit:{x,y}, log:string[], goal:{x,y}}.
Tile: {type:'floor'|'wall'|'water'|'gate'|'exit', elevation:number, zone:string, variant?:number}. Treat low floor as flooded when tide>=elevation; expose is_flooded(run,x,y), is_walkable(run,x,y) from world_data.gd. Walls remain opaque until destroyed. Tide must not kill the player while simply reading menus.
Enemy: {id:string, kind:string, x,y,hp, facing?:{x,y}, intent?:{dx,dy}, stunned?:number, target?:{x,y}}. Enemy kind keys: crab (adjacent), wader (telegraphed charge), diver (slow heavy guard).
Container: {id:string,x,y,items:Item[],searched:boolean}. Search adjacent or same tile, transferring only what fits, retaining overflow. No invisible discarded loot.
Result: {outcome:'extracted'|'dead', inventory:Item[], turns:number, cause:string, value:number}. Result inventory is a receipt of items already transferred or lost, not another active ownership location.

Actions:
- {type:'pack',uid} / {type:'unpack',uid} in harbor.
- {type:'depart',seed?}. Generate coherent map, fresh enemies and loot. Move packed items into run. Fill missing basic weapon with a non-sellable loan knife; after death a player can always depart again. The loan knife is returned on extraction and excluded from the receipt; it cannot duplicate stash items.
- {type:'move',dx,dy} cardinal unit steps; bump attacks enemy. Blocked movement does not consume a turn.
- {type:'wait'}.
- {type:'interact'} searches nearest adjacent container; if standing on exit, extracts (UI asks confirmation first).
- {type:'use',uid,dx?,dy?} uses a consumable; bomb targets adjacent tile and affects wall/enemy, flare lures nearby foes, medicine heals. Out-of-range, no-effect use does not spend item or turn.
- {type:'equip',uid} weapon/armor only; one turn during an expedition.
- {type:'drop',uid} drops into a ground container without destroying item; one turn during expedition.
- {type:'return'} result -> harbor; never transfers inventory again.
- {type:'repair'}: backward-compatible alias for claiming the `beacon` contract, with the same UID consumption and one-time reward.
- {type:'choose_district',district}: harbor only; requires the district prerequisite contract. Selection persists and is copied to `run.district` on departure.
- {type:'accept_contract',id}: harbor only; sets the tracked job and its unlocked district. Tracking is optional for delivery; any unlocked ready job may be claimed, so changing the tracked job does not discard recovered progress.
- {type:'claim_contract',id}: harbor only; consumes exact required stash items and grants credits/items once. Requirements in loadout, run inventory and result receipts cannot be spent. The first story contract also sets lampRepaired and adds FOV +1 on the next departure.
- {type:'sell',uid}: removes one actual stash item and credits its recorded ITEMS value. Loans cannot be sold. No sale of a packed/carried item or result receipt.
- {type:'buy',kind}: requires a recorded SHOP kind and sufficient credits; pays once and creates a fresh UID in stash. Buy prices exceed sale values. Purchases are exposed with actual affordability, and all exchange actions are harbor-only.

Campaign content is in `campaign_data.gd`: four story contracts (`beacon`, `pump`, `channel`, `network`) sequentially unlock quay, market, canal and observatory; four optional personal deliveries (`isana_parcel`, `ritsu_clinic`, `kohaku_tools`, `sui_atlas`) change the corresponding worker's actual dialogue and grant concrete equipment/credits. No XP or new character-stat progression. The lamp flag must agree with beacon completion. Credits, completed jobs and stash survive death; the entire carried inventory is still lost. The initial tracked job is beacon.

Story deliveries: beacon=core1+scrap1; pump=pumpGear1+scrap2; channel=chart1+pearl1; network=sunLens1+pumpGear1. The market objective cache contains two pump gears, so the fourth delivery can use its spare without a mandatory repeat run. Credits reward20/24/28/40. Personal deliveries and supply prices are recorded as data, not UI-only promises.

world_data.gd exports create_world(seed, lampRepaired=false, district="quay"): world data using deterministic seeded RNG. Calls with the original two parameters retain the quay layout and loot/enemy generation. Every district is25x25 with exit(12,23), an adjacent supply cache, an objective and at least one elevated objective-to-exit route that remains dry at tide3.

- Quay keeps the original continuous northbound spine and lighthouse branch; goal(21,3), core.
- Market encloses a low courtyard with side doors, two elevated flanking alleys and north/south crossstreets; goal(12,4), two pumpGear items plus two scrap. Seed chooses one elevated side doorway and varies caches/enemy positions.
- Canal joins separate islands by zigzag dry bridges, with shorter low causeways that flood; goal(19,4), chart. Bridge intersections remain raised even where a low shortcut crosses them.
- Observatory places a raised ring around a low inner terrace and a guarded north cache; goal(12,3), sunLens. Either outer arm stays dry; seed chooses one raised inner stair.

District palette and decorative landmark anchors are declared in CampaignData. Decorative anchors must match actual wall/water tiles; goals and loot stay walkable and visible according to fog. Rendering must read `run.goal`, `run.district` and the current map, without painting fixed quay architecture over another district.

Storage keeps the existing `shiogaeri-save-v1` key. Loading a valid version1 harbor, result or in-flight run preserves positions, turns, tide, HP, facing, equipment, inventory, enemies/intents/lures, containers, knowledge, logs, receipt and IDs. It adds quay selection/run district, zero credits and beacon completion only when the old lamp was already repaired; it grants no retroactive reward. Before the first version2 write, save_store retains the exact original raw bytes under `shiogaeri-save-v1-pre-v2` (Web) or `user://expedition.pre-v2.json` (native). A failed backup returns an error and refuses to overwrite the original. Invalid/unsupported data remains untouched on load. Native normal saves still use temp-file replacement and a previous-save backup.

Events may use move, attack, hurt, kill, loot, use, tide, death, extract, equip, depart, repair, message. Every has human-readable text. Effects and audio use event type but never change engine state. Copy the resulting state at a resolved turn boundary for atomic browser localStorage writes (native builds use a temp-file replacement). Reload and visibility changes do not call apply_action.
