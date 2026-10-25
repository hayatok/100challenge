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
- validate_state(value): boolean; strictly reject malformed or unsupported saves. UI will call before loading.

State: {version:1, character:'isana'|'ritsu'|'kohaku'|'sui', mode:'harbor'|'expedition'|'result', profile:{stash:Item[], runs:number, extracts:number, deaths:number, lampRepaired:boolean}, loadout:Item[], run:null|Run, result:null|Result, nextId:number}.
Item: {uid:string, kind:string}. Unique uid across all places. Equipment is in inventory and takes capacity.
Run: {seed:number, turn:number, tide:number, player:{x,y,hp,maxHp,facing:{x,y}}, inventory:Item[], weapon:string|null, armor:string|null, tiles:Tile[][], width,height, enemies:Enemy[], containers:Container[], seen:string[], exit:{x,y}, log:string[], goal:{x,y}}.
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
- {type:'repair'} harbor only, consumes specified recovered core/material and updates lampRepaired. Show real benefit on next departure (FOV +1).

world_data.gd also exports create_world(seed, lampRepaired): world data, using deterministic seeded RNG. Preserve safe elevated return paths. Suggested 25x25 world, exit near south edge, recognizable harbor/market/clinic/lighthouse sectors. Use reachable graph and varied loot/patrols, not disconnected random cells.

Events may use move, attack, hurt, kill, loot, use, tide, death, extract, equip, depart, repair, message. Every has human-readable text. Effects and audio use event type but never change engine state. Copy the resulting state at a resolved turn boundary for atomic browser localStorage writes (native builds use a temp-file replacement). Reload and visibility changes do not call apply_action.
