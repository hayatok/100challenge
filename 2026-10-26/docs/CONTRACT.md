# Implementation contract

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
