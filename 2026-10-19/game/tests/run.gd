extends SceneTree

const Run = preload("res://scripts/run_model.gd")
const Timeline = preload("res://scripts/echo_timeline.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Arena = preload("res://scripts/arena_grid.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_test_history()
	_test_echo_payload()
	_test_freeze()
	_test_progression_choices()
	_test_replacement()
	_test_specialization_and_resonance()
	_test_weapons_and_evolutions()
	_test_relics_and_drops()
	_test_geometry_and_routing()
	_test_hazards_and_bosses()
	_test_chapter_transition_and_reset()
	_test_snapshot()
	_test_choice_limits_and_status_boundaries()
	_test_campaign_growth_gates_and_chest_clock()
	if failures.is_empty():
		print("PASS: %d campaign checks (2s echo, immutable relics, freeze, choices, replacement, six weapons/evolutions, relics/drops, routing, bosses/chapters)" % checks)
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func empty_run():
	var run = Run.new()
	run.reset(true, 731)
	run.enemies.clear()
	run.chests.clear()
	run.spawn_clock = 10000.0
	for id in Spellbook.WEAPON_IDS:
		run.cooldowns[id] = 10000.0
	return run

func advance(run, seconds: float, movement: Vector2 = Vector2.ZERO) -> void:
	for i in range(roundi(seconds * 60.0)):
		run.tick(1.0 / 60.0, movement)

func target(run, hp: float = 1000.0, at: Vector2 = Vector2(160, 0)) -> Dictionary:
	var enemy: Dictionary = run.spawn_enemy("hound", at)
	enemy.phase = "seek"
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.speed = 0.0
	enemy.contact_ready_at = 10000.0
	return enemy

func offer_choice(run, id: String, treasure: bool = false) -> void:
	run.state = "treasure" if treasure else "upgrade"
	run.choice_phase = "offer"
	run.choices.assign([Spellbook.offer(id, run.weapons, run.speed, run.maximum_health)])

func _test_history() -> void:
	var history = Timeline.new()
	history.reset(Vector2.ZERO)
	history.record_position(1.0, Vector2(100, 20))
	history.record_position(2.0, Vector2(200, 40))
	expect(history.position_at(0.5).is_equal_approx(Vector2(50, 10)), "History interpolates real samples")
	var payload := {"kind": "lightning", "damage": 12.0, "nested": {"echo_multiplier": 1.3}}
	history.record_attack(0.5, payload)
	payload.nested.echo_multiplier = 9.0
	expect(history.consume_attacks(2.499).is_empty(), "Echo cannot fire early")
	var ready: Array = history.consume_attacks(2.5)
	expect(ready.size() == 1 and ready[0].nested.echo_multiplier == 1.3, "Echo payload is an exact deep snapshot")
	expect(history.consume_attacks(8.0).is_empty(), "Consumed attack never recurs")

func _test_echo_payload() -> void:
	var moving = empty_run()
	advance(moving, 3.0, Vector2.RIGHT)
	expect(moving.echo_active and absf(moving.player.x - 645.0) < 0.02 and absf(moving.echo.x - 215.0) < 0.02, "Production position echo retains exactly two seconds")
	expect(moving.timeline.positions.size() < 135, "Position history stays bounded")
	var run = empty_run()
	run.relics.assign(["lantern_oil", "thorn_seed", "ice_crystal"])
	var first := target(run)
	run.cooldowns.lightning = 0.0
	run._update_weapons(1.0 / 60.0)
	expect(run.timeline.attacks.size() == 1 and is_equal_approx(first.hp, 988.0), "Normal lightning damages a live target")
	var recorded: Dictionary = run.timeline.attacks[0].payload.duplicate(true)
	run.relics.clear()
	run.weapons.lightning.damage = 90.0
	run.enemies.clear()
	var other := target(run, 1000.0, Vector2(-160, 0))
	run.cooldowns.lightning = 10000.0
	advance(run, 1.9)
	expect(run.echo_shots == 0, "Production echo waits two full seconds")
	advance(run, 0.2)
	expect(run.echo_shots == 1 and run.player_shots == 1, "Echo fires once and does not record itself")
	expect(run.last_echo_attack == recorded and run.timeline.attacks.is_empty(), "Replacing relics or raising ranks never rewrites a queued attack")
	expect(is_equal_approx(run.last_echo_attack.echo_multiplier, 1.3) and float(other.hp) < 984.5 and is_equal_approx(other.poison_dps, 3.9) and other.slow_scale == 0.7, "Delayed replay keeps echo-only damage, poison, and slow relic modifiers")
	var no_oil = empty_run()
	var a := target(no_oil)
	no_oil.cooldowns.lightning = 0.0
	no_oil._update_weapons(0.01)
	no_oil.relics.assign(["lantern_oil"])
	no_oil.cooldowns.lightning = 10000.0
	advance(no_oil, 2.02)
	expect(no_oil.last_echo_attack.echo_multiplier == 1.0 and is_equal_approx(a.hp, 976.0), "A newly acquired echo relic cannot strengthen an earlier queued attack")

func _test_freeze() -> void:
	var run = empty_run()
	var enemy := target(run)
	enemy.phase = "warning"
	enemy.timer = 0.8
	run._add_hazard("circle", Vector2(100, 0), 50, 0, 1.0, 0.5, 10, "boss_thorn")
	run.projectiles.append({"kind": "bolt", "position": Vector2(300, 0), "velocity": Vector2.LEFT * 100, "age": 0.0, "duration": 4.0, "damage": 10})
	run.effects.append({"kind": "hurt", "position": Vector2.ZERO, "age": 0.0, "duration": 0.5})
	run.relics.assign(["ward_leaf"])
	run.ward_cooldown = 10.0
	run.timeline.record_attack(0.0, {"kind": "moon", "damage": 13.0, "radius": 118.0, "count": 1})
	for frozen_state in ["paused", "upgrade", "treasure", "chapter_clear", "defeat", "victory"]:
		run.state = frozen_state
		var before := JSON.stringify(run.snapshot())
		advance(run, 3.0, Vector2.RIGHT)
		expect(JSON.stringify(run.snapshot()) == before and enemy.timer == 0.8 and run.hazards[0].age == 0.0 and run.projectiles[0].age == 0.0 and run.effects[0].age == 0.0 and run.ward_cooldown == 10.0, "Every gameplay clock freezes in " + frozen_state)
	run.state = "playing"
	run.pause("focus lost")
	advance(run, 1.0)
	expect(run.state == "paused", "Focus return never resumes automatically")
	run.resume()
	run.tick(0.01)
	expect(run.elapsed > 0.0 and enemy.timer < 0.8 and run.hazards[0].age > 0.0 and run.ward_cooldown < 10.0, "Explicit resume advances all clocks together")

func _test_progression_choices() -> void:
	var run = empty_run()
	run.experience = run.experience_needed
	run.check_level_up()
	expect(run.state == "upgrade" and run.level == 2 and run.choices.size() == 3, "Real XP produces three growth choices")
	expect(run.choices[0].id == "weapon:moon" and run.choose_upgrade(0) and run.weapons.moon.level == 1, "First choice teaches the second weapon")
	expect(not run.choose_upgrade(2), "Chooser rejects input while playing")
	run.experience = run.experience_needed
	run.check_level_up()
	var old_ids: Array = []
	for card in run.choices:
		old_ids.append(card.id)
	expect(run.reroll_choices() and run.rerolls_left == 2 and run.choices.size() == 3, "Reroll consumes one shared charge and offers three cards")
	var fresh := true
	for card in run.choices:
		fresh = fresh and card.id not in old_ids
	expect(fresh, "Reroll changes the actual options")
	var equipment := JSON.stringify(run.equipment_info())
	expect(run.skip_choice() and run.skips_left == 2 and run.state == "playing" and JSON.stringify(run.equipment_info()) == equipment, "Skip consumes a charge without changing equipment")
	run.level = 3
	run.experience = run.experience_needed
	run.check_level_up()
	expect(run.choices.size() == 3 and run.choices[0].specialization and not run.reroll_choices(), "Rank-independent level-four specializations cannot be rerolled away")

func _test_replacement() -> void:
	var early = empty_run()
	offer_choice(early, "relic:storm_ink")
	early.choose_upgrade(0)
	early.experience = early.experience_needed
	early.check_level_up()
	var legal := true
	for early_card in early.choices:
		legal = legal and early_card.id != "relic:storm_ink"
	expect(legal and early.choices.size() == 3, "An early treasure relic cannot reappear as an illegal level-two reward")
	var run = empty_run()
	Spellbook.rank_weapon("moon", run.weapons)
	Spellbook.rank_weapon("thorn", run.weapons)
	var cards := Spellbook.offers(run.weapons, 6, run.speed, run.maximum_health, run.rng, "雷の魔女", run.relics)
	var card := Spellbook.offer("weapon:wisp", run.weapons)
	card.full_slots = true
	run.state = "upgrade"
	run.choices.assign([card])
	expect(run.choose_upgrade(0) and run.choice_phase == "replace" and run.choices.size() == 3 and run.weapons.wisp.level == 0, "Full weapon slots open a real three-way comparison before mutation")
	expect(not str(run.choices[0].before).is_empty() and not str(run.choices[0].after).is_empty(), "Replacement cards show the equipment lost and gained")
	expect(run.cancel_replacement() and run.choice_phase == "offer" and Spellbook.equipped_ids(run.weapons).size() == 3, "Replacement can be cancelled without spending a reward")
	run.choose_upgrade(0)
	var replaced := str(run.choices[1].replace_id)
	expect(run.choose_upgrade(1) and run.weapons[replaced].level == 0 and run.weapons.wisp.level == 1 and Spellbook.equipped_ids(run.weapons).size() == 3, "Confirmed replacement removes precisely the selected weapon")
	run.relics.assign(["swift_boots", "moonstone", "ward_leaf"])
	run._refresh_relic_stats()
	card = Spellbook.offer("relic:magnet_ring", run.weapons)
	card.full_slots = true
	run.state = "treasure"
	run.choices.assign([card])
	run.choose_upgrade(0)
	expect(run.state == "treasure" and run.choices.size() == 3 and run.choice_phase == "replace", "Treasure uses the same explicit relic replacement flow")
	expect(run.choose_upgrade(0) and "swift_boots" not in run.relics and "magnet_ring" in run.relics and run.relics.size() == 3 and run.speed == 215.0 and run.pickup_radius == 262.0, "Replacing a relic removes its real effect and applies the new effect")
	expect(cards.size() == 3, "A full loadout still gets three legal offers")

func _test_specialization_and_resonance() -> void:
	var lightning = empty_run()
	offer_choice(lightning, "spec_lightning")
	expect(lightning.choose_upgrade(0) and lightning.specialization == "雷の魔女" and is_equal_approx(lightning.weapons.lightning.damage, 16.8) and is_equal_approx(lightning.weapons.moon.damage, 9.1), "Lightning specialization keeps its explicit benefit and cost")
	Spellbook.rank_weapon("lightning", lightning.weapons)
	expect(is_equal_approx(lightning.weapons.lightning.damage, 19.6), "Later ranks preserve specialization multipliers")
	offer_choice(lightning, "spec_echo")
	expect(not lightning.choose_upgrade(0) and lightning.specialization == "雷の魔女", "Specializations are exclusive even for stale input")
	var moon = empty_run()
	offer_choice(moon, "spec_moon")
	expect(moon.choose_upgrade(0) and moon.weapons.moon.level == 1 and is_equal_approx(moon.weapons.moon.radius, 165.2) and is_equal_approx(moon.weapons.lightning.range, 300.0), "Moon specialization grants its real second weapon and range tradeoff")
	var run = empty_run()
	run.elapsed = 5.0
	run.player = Vector2(150, 0)
	run.echo = Vector2(-150, 0)
	run.echo_active = true
	var enemy := target(run, 36.0, Vector2(0, 130))
	run.damage_enemy(enemy, 12, Vector2.ZERO, false)
	run.damage_enemy(enemy, 12, Vector2.ZERO, true)
	expect(run.resonance_hits == 1 and run.resonance_kills == 1 and enemy.hp == 0.0 and run.experience == 1, "Separated alternating sources add twelve real damage and one XP")
	var survivor := target(run, 200.0)
	run.damage_enemy(survivor, 1, Vector2.ZERO, false)
	run.damage_enemy(survivor, 1, Vector2.ZERO, false)
	expect(run.resonance_hits == 1, "One source cannot self-trigger resonance")
	run.damage_enemy(survivor, 1, Vector2.ZERO, true)
	run.damage_enemy(survivor, 1, Vector2.ZERO, false)
	expect(run.resonance_hits == 2 and run.experience == 2, "Resonance cooldown prevents repeated immediate triggers")
	run.elapsed += 2.6
	run.damage_enemy(survivor, 1, Vector2.ZERO, false)
	run.damage_enemy(survivor, 1, Vector2.ZERO, true)
	expect(run.resonance_hits == 3 and run.experience == 2, "A surviving target cannot farm unlimited resonance XP")
	run.echo = run.player
	var overlapping := target(run)
	run.damage_enemy(overlapping, 1, Vector2.ZERO, false)
	run.damage_enemy(overlapping, 1, Vector2.ZERO, true)
	expect(run.resonance_hits == 3, "Overlapping actors do not earn flanking damage")

func _test_weapons_and_evolutions() -> void:
	expect(Spellbook.WEAPON_IDS.size() == 6 and Spellbook.RELIC_IDS.size() == 12, "Production content has six weapons and twelve relics")
	for id in Spellbook.WEAPON_IDS:
		var run = empty_run()
		run.weapons = Spellbook.initial_weapons(id)
		var enemy := target(run, 1000.0, Vector2(120, 0))
		run.cooldowns[id] = 0.0
		advance(run, 1.1)
		expect(run.player_shots > 0 and float(enemy.hp) < 1000.0, id + " actually casts and damages through its production projectile behavior")
		var locked := Spellbook.initial_weapons(id)
		expect(not Spellbook.evolve_weapon(id, locked, [Spellbook.weapon_info(id).requirement], 2, true), id + " cannot evolve before Rank 5")
		for n in range(4):
			Spellbook.rank_weapon(id, run.weapons)
		expect(int(run.weapons[id].level) == 5 and not Spellbook.rank_weapon(id, run.weapons), id + " has a real Rank 5 cap")
		var relic_id := str(Spellbook.weapon_info(id).requirement)
		expect(not Spellbook.evolve_weapon(id, run.weapons, [], 2, true), id + " needs its matching relic to evolve")
		run.relics.assign([relic_id])
		run.chapter = 2
		offer_choice(run, "evolve:" + id, true)
		expect(run.choose_upgrade(0) and bool(run.weapons[id].evolved) and id in run.discoveries.evolutions, id + " evolution is a chosen and recorded equipment change")
		var payload: Dictionary = run._capture_payload(id, false)
		expect(payload.evolved and float(payload.damage) > 0.0 and not Spellbook.evolve_weapon(id, run.weapons, [relic_id], 2, true), id + " evolution is functional and cannot be stacked")
		var first_hp := float(enemy.hp)
		run.cast(payload, Vector2.ZERO, false)
		advance(run, 1.2)
		expect(float(enemy.hp) < first_hp, id + " evolved attack damages through the real cast path")
	var lightning = empty_run()
	var a := target(lightning, 200.0, Vector2(120, 0))
	var b := target(lightning, 200.0, Vector2(240, 0))
	var data: Dictionary = lightning.weapons.lightning.duplicate(true)
	data.kind = "lightning"
	data.count = 2
	lightning.cast(data, Vector2.ZERO, false)
	expect(is_equal_approx(a.hp, 188.0) and is_equal_approx(b.hp, 188.0), "Multiple lightning rays share hit IDs and cannot multiply one cast on a single enemy")

func _test_relics_and_drops() -> void:
	var run = empty_run()
	run.relics.assign(["storm_ink"])
	var normal: Dictionary = run._capture_payload("lightning")
	run._capture_payload("lightning")
	run._capture_payload("lightning")
	var fourth: Dictionary = run._capture_payload("lightning")
	expect(is_equal_approx(normal.damage, 12.0) and fourth.empowered and is_equal_approx(fourth.damage, 17.4), "Static ink strengthens exactly every fourth original cast")
	run.relics.assign(["moonstone", "ice_crystal", "thorn_seed"])
	var area: Dictionary = run._capture_payload("moon", false)
	expect(is_equal_approx(area.radius, 143.96) and area.slow == 0.7 and area.slow_duration == 1.2 and area.poison == 3.0 and area.poison_duration == 3.0, "Area, ice and thorn relics enter the actual attack payload")
	run.relics.assign(["hourglass", "swift_boots", "echo_mirror"])
	run._refresh_relic_stats()
	var fast: Dictionary = run._capture_payload("lightning", false)
	expect(is_equal_approx(run.speed, 247.25) and is_equal_approx(fast.cooldown, 0.663) and is_equal_approx(fast.damage, 9.936) and fast.resonance_distance == 70.0 and fast.resonance_bonus == 22.0, "Speed and haste relics keep their real damage costs; mirror changes flanking range and payoff")
	run.relics.assign(["silver_bell"])
	expect(run._capture_payload("bell", false).resonance_stagger == 0.45, "Silver tuning fork records its stagger for delayed hits")
	var shield = empty_run()
	shield.relics.assign(["ward_leaf"])
	shield._refresh_relic_stats()
	shield.take_damage(10)
	expect(shield.health == 100.0 and shield.ward_charges == 0, "A leaf shield really blocks one damage event")
	advance(shield, 17.0)
	expect(shield.ward_charges == 0, "Leaf shield cannot regenerate early")
	advance(shield, 1.1)
	expect(shield.ward_charges == 1, "Leaf shield returns after eighteen simulation seconds")
	var blood = empty_run()
	blood.relics.assign(["blood_vial"])
	blood._refresh_relic_stats()
	blood.health = 60.0
	for i in range(12):
		var enemy := target(blood)
		enemy.hp = 0.0
	blood._cleanup_dead()
	expect(blood.maximum_health == 124.0 and blood.health == 62.0, "Blood vial grants max health and the specified twelve-kill recovery")
	var drops = empty_run()
	drops.health = 60.0
	var enemy := target(drops, 200.0, Vector2(100, 0))
	for role in ["heal", "magnet", "ward", "blast"]:
		drops.pickups.append({"position": Vector2.ZERO, "kind": role, "value": 20 if role == "heal" else 1})
	advance(drops, 0.05)
	expect(drops.health == 80.0 and drops.ward_charges == 1 and drops._magnet_time > 3.9 and is_equal_approx(enemy.hp, 125.0), "All four drop roles activate by actual contact collection")
	var xp = empty_run()
	xp.relics.assign(["magnet_ring"])
	xp._refresh_relic_stats()
	for i in range(5):
		xp._collect_pickup({"kind": "xp", "value": 1})
	expect(xp.experience == 6 and xp.pickup_radius == 262.0, "XP relic keeps fractional gain and grants exactly twenty percent")
	var elite = empty_run()
	var guard: Dictionary = elite.spawn_enemy("charger", Vector2(150, 0), true)
	guard.hp = 0.0
	elite._cleanup_dead()
	expect(elite.chests.size() == 1 and elite.chests[0].elite and elite.pickups.size() >= 2, "Defeated elites create a real treasure chest and drops")
	elite.player = elite.chests[0].position
	elite._update_chests()
	expect(elite.state == "treasure" and elite.chests[0].opened and elite.choices.size() == 3, "Elite treasure opens on contact and freezes for three choices")

func _test_geometry_and_routing() -> void:
	for chapter_index in range(3):
		var arena = Arena.new()
		var info := Campaign.chapter(chapter_index)
		arena.configure(info)
		expect(arena.is_clear(Vector2.ZERO) and info.obstacles.size() >= 4, "Each authored chapter has a clear start and meaningful solids")
		var blocked := true
		for solid in info.obstacles:
			blocked = blocked and not arena.is_clear((solid as Rect2).get_center())
		expect(blocked and not arena.is_clear(Vector2(1200, 0)), "Chapter solids and outer bounds block movement")
		var walker := {"id": 1, "position": Vector2(-850, -250), "radius": 17.0, "nav_clock": 0.0, "nav_path": PackedVector2Array()}
		var destination := Vector2(0, -250)
		for frame in range(900):
			var direction := arena.route(walker, destination, 1.0 / 60.0)
			walker.position = arena.move(walker.position, direction * 120.0 / 60.0, 17.0)
			expect(arena.is_clear(walker.position, 17.0), "Routed enemy remains outside solids")
		expect((walker.position as Vector2).distance_to(destination) < 70.0, "Enemy routes around authored chapter obstacles instead of stalling")
	var run = empty_run()
	run.player = Vector2(-190, -280)
	advance(run, 1.0, Vector2.LEFT)
	expect(run.player.x > -207.0 and run.arena.is_clear(run.player), "Player cannot walk into a planter")
	run.player = Vector2(1070, 0)
	advance(run, 2.0, Vector2.RIGHT)
	expect(run.player.x <= 1086.0 and run.arena.is_clear(run.player), "Player remains inside the bounded arena")

func _test_hazards_and_bosses() -> void:
	var warning = empty_run()
	warning._add_hazard("circle", Vector2.ZERO, 80, 0, 1.0, 0.3, 14, "boss_thorn")
	advance(warning, 0.95)
	expect(warning.health == 100.0, "A hazard warning is harmless for its full advertised delay")
	advance(warning, 0.1)
	expect(warning.health == 86.0 and warning.damage_received.hazard == 14.0 and warning.last_damage_cause == "boss_thorn", "Circle becomes damaging at the advertised time and records its cause")
	var ring = empty_run()
	ring._add_hazard("ring", Vector2.ZERO, 150, 30, 0, 1.0, 10, "boss_bell")
	advance(ring, 0.1)
	expect(ring.health == 100.0, "A ring's hollow center is safe")
	ring.player = Vector2(150, 0)
	advance(ring, 0.1)
	expect(ring.health == 90.0, "A ring damages its full-width centerline band")
	var line = empty_run()
	line.player = Vector2(0, 80)
	line._add_line(Vector2(-200, 0), Vector2(200, 0), 40, 0, 1.0, 10, "boss_mirror")
	advance(line, 0.1)
	expect(line.health == 100.0, "The visible space outside a line remains safe")
	line.player = Vector2(0, 28)
	advance(line, 0.1)
	expect(line.health == 90.0, "Line collision uses half of the advertised full width plus player radius")
	for chapter_index in range(3):
		var run = empty_run()
		run.chapter = chapter_index
		run._chapter_data = Campaign.chapter(chapter_index)
		run.arena.configure(run._chapter_data)
		run.chapter_elapsed = 179.98
		run.tick(0.04)
		var boss: Dictionary = run.boss_data()
		expect(run.state == "playing" and run.chapter_stage == "boss" and not boss.is_empty() and boss.id == Campaign.chapter(chapter_index).boss_id, "180 seconds summons a chapter-specific boss instead of awarding victory")
		var enemy: Dictionary = run.enemies[0]
		enemy.phase = "seek"
		run._boss_pattern(enemy)
		expect(not run.hazards.is_empty(), "Each boss produces real telegraphed attacks")
		enemy.hp = float(enemy.max_hp) * 0.49
		run._update_enemies(0.01)
		expect(enemy.phase_index == 2, "Each boss changes phase below half health")
		var recovery_drop := false
		for pickup in run.pickups:
			recovery_drop = recovery_drop or pickup.get("kind", "xp") == "heal"
		expect(recovery_drop, "Boss phase change offers a real recoverable health drop")
		run.damage_enemy(enemy, float(enemy.max_hp), Vector2.ZERO, false)
		run._cleanup_dead()
		expect(run.chapter_clears == [chapter_index] and run.state == ("victory" if chapter_index == 2 else "chapter_clear"), "Only defeating the boss clears a chapter or wins the campaign")
	var lost = empty_run()
	lost.take_damage(100)
	expect(lost.state == "defeat" and lost.health == 0.0, "Zero HP ends the run immediately")

func _test_chapter_transition_and_reset() -> void:
	var run = empty_run()
	Spellbook.rank_weapon("moon", run.weapons)
	run.relics.assign(["moonstone"])
	run.level = 6
	run.health = 50.0
	run.elapsed = 230.0
	run.chapter_elapsed = 230.0
	run.state = "chapter_clear"
	run.chapter_clears.assign([0])
	run.timeline.record_attack(230, {"kind": "moon"})
	run.timeline.record_position(230, Vector2(600, 0))
	run.hazards.append({"shape": "circle"})
	run.projectiles.append({"kind": "bolt"})
	run.pickups.append({"position": Vector2.ONE, "value": 5})
	expect(run.next_chapter() and run.chapter == 1 and run.chapter_elapsed == 0.0 and run.elapsed == 230.0 and run.level == 6 and run.weapons.moon.level == 1 and run.relics == ["moonstone"], "Chapter transition carries the run build and total time")
	expect(run.health == 72.0 and run.projectiles.is_empty() and run.hazards.is_empty() and run.pickups.is_empty() and run.timeline.attacks.is_empty() and run.timeline.positions.size() == 1 and not run.echo_active, "Chapter transition heals modestly and clears every old battle/history object")
	run.enemies.clear()
	run.chests.clear()
	run.spawn_clock = 10000
	advance(run, 1.9, Vector2.RIGHT)
	expect(not run.echo_active and run.echo_shots == 0, "A new chapter requires a fresh two-second echo delay")
	advance(run, 0.2, Vector2.RIGHT)
	expect(run.echo_active and run.echo.x < 30.0, "New chapter echo samples the new chapter, not the prior chapter's end")
	run.reset(false, 731, "frost")
	expect(run.state == "title" and run.elapsed == 0.0 and run.chapter == 0 and run.chapter_clears.is_empty() and run.weapons.frost.level == 1 and run.relics.is_empty(), "Reset clears campaign progression and honors an unlocked starter")
	expect(run.enemies.is_empty() and run.chests.is_empty() and run.timeline.attacks.is_empty() and run.rerolls_left == 3 and run.skips_left == 3 and run.damage_taken == 0.0, "Reset clears enemies, drops, history, counters, and damage")
	run.reset(true, 731)
	expect(run.state == "playing" and run.enemies.size() == 5 and run.chests.is_empty() and run.health == 100.0, "Retry creates a complete fresh first chapter")

func _test_snapshot() -> void:
	var preview = empty_run()
	preview.relics.assign(["moonstone", "hourglass", "swift_boots"])
	Spellbook.rank_weapon("moon", preview.weapons)
	preview.state = "upgrade"
	preview.choices.assign([Spellbook.offer("weapon:moon", preview.weapons)])
	preview._decorate_choices()
	var advertised: String = preview.choices[0].after
	preview.choose_upgrade(0)
	var actual: String = Spellbook.weapon_summary(preview._capture_payload("moon", false), "moon")
	expect(advertised == actual, "Choice preview includes every currently equipped relic modifier and exactly matches the acquired weapon")
	var run = Run.new()
	run.reset(true, 731)
	var value: Dictionary = run.snapshot()
	var encoded := JSON.stringify(value)
	var parsed: Variant = JSON.parse_string(encoded)
	expect(parsed is Dictionary and parsed.arena.bounds.width == 2200 and parsed.arena.obstacles.size() == 4 and parsed.chests.is_empty() and parsed.rank_cap == 3 and parsed.speed == 215.0, "Snapshot provides JSON geometry and movement speed for read-only observation")
	expect(parsed.discoveries.weapons == ["lightning"] and parsed.equipment.weapon_slots == 3 and parsed.equipment.relic_slots == 3 and parsed.damage_summary.by_weapon.has("bell"), "Snapshot provides concrete discoveries, equipment slots, and actual damage accounting")
	value.weapons.lightning.damage = 9999
	value.choices.append({"id": "fake"})
	expect(run.weapons.lightning.damage == 12 and run.choices.is_empty(), "Mutating a snapshot cannot change the game")


func _test_choice_limits_and_status_boundaries() -> void:
	var capped = empty_run()
	for id in ["lightning", "moon", "bell"]:
		while int(capped.weapons[id].level) < 5:
			Spellbook.rank_weapon(id, capped.weapons)
		capped.relics.append(str(Spellbook.weapon_info(id).requirement))
		Spellbook.evolve_weapon(id, capped.weapons, capped.relics, 2, true)
	var safe_fallback := true
	for i in range(20):
		var cards := Spellbook.offers(capped.weapons, 20, capped.speed, capped.maximum_health, capped.rng, "雷の魔女", capped.relics)
		var has_heal := false
		var unique := {}
		for card in cards:
			has_heal = has_heal or card.id == "heal"
			unique[card.id] = true
			safe_fallback = safe_fallback and not str(card.id).begins_with("evolve:")
		safe_fallback = safe_fallback and has_heal and unique.size() == 3
	expect(safe_fallback, "A fully grown loadout always has three unique legal choices and a safe recovery option")
	capped._open_choices(false)
	capped.rerolls_left = 0
	capped.skips_left = 0
	var cards_before := JSON.stringify(capped.choices)
	expect(not capped.reroll_choices() and not capped.skip_choice() and JSON.stringify(capped.choices) == cards_before, "Exhausted reroll/skip counters cannot mutate the current reward")
	var moon = empty_run()
	Spellbook.rank_weapon("thorn", moon.weapons)
	Spellbook.rank_weapon("wisp", moon.weapons)
	var specialization := Spellbook.offer("spec_moon", moon.weapons)
	specialization.full_slots = true
	moon.state = "upgrade"
	moon.choices.assign([specialization])
	moon.choose_upgrade(0)
	expect(moon.choice_phase == "replace" and not moon.skip_choice() and not moon.reroll_choices(), "A full-slot specialization requires a real replacement and cannot consume unrelated skip/reroll charges")
	moon.choose_upgrade(0)
	expect(moon.specialization == "月の魔女" and moon.weapons.moon.level == 1 and Spellbook.equipped_ids(moon.weapons).size() == 3, "Moon specialization respects the same three-weapon budget")
	var poison = empty_run()
	poison.relics.assign(["thorn_seed", "hourglass", "swift_boots"])
	offer_choice(poison, "spec_echo")
	poison.choose_upgrade(0)
	var weak: Dictionary = poison._capture_payload("thorn", false)
	expect(is_equal_approx(weak.poison, 6.0 * 0.85 * 0.9 * 0.92), "Poison respects specialization and the same explicit power costs as the originating spell")
	var thorn = empty_run()
	thorn.weapons = Spellbook.initial_weapons("thorn")
	var enemy := target(thorn, 1000, Vector2(100, 0))
	var payload: Dictionary = thorn._capture_payload("thorn", false)
	thorn.cast(payload, Vector2.ZERO, false)
	advance(thorn, 0.5)
	var normal_damage := float(thorn.damage_summary.player)
	expect(is_equal_approx(normal_damage, 13.0) and float(enemy.hp) < 987.0, "A thorn fan hits one enemy once per cast, while its separate poison continues")
	var detached = empty_run()
	detached.weapons = Spellbook.initial_weapons("frost")
	while int(detached.weapons.frost.level) < 5:
		Spellbook.rank_weapon("frost", detached.weapons)
	detached.relics.assign(["ice_crystal"])
	Spellbook.evolve_weapon("frost", detached.weapons, detached.relics, 2, true)
	detached.relics.clear()
	expect(detached.weapons.frost.evolved and detached._capture_payload("frost", false).stagger == 0.25, "An already chosen evolution survives replacing its enabling relic")
	var incoming = empty_run()
	incoming.projectiles.append({"kind": "bolt", "position": Vector2(20, 0), "velocity": Vector2.LEFT * 240, "age": 0.0, "duration": 1.0, "damage": 10.0, "source": "archer", "radius": 7.0})
	advance(incoming, 0.05)
	expect(incoming.health == 90.0 and incoming.damage_received.projectile == 10.0 and incoming.last_damage_cause == "archer", "Actual hostile projectile contact records its distinct received-damage cause")
	var total := float(thorn.damage_summary.player) + float(thorn.damage_summary.echo) + float(thorn.damage_summary.poison) + float(thorn.damage_summary.resonance)
	var by_weapon := 0.0
	for amount in thorn.damage_summary.by_weapon.values():
		by_weapon += float(amount)
	expect(is_equal_approx(total, by_weapon), "Damage totals partition actual non-overkill damage without double-counting status or resonance")


func _test_campaign_growth_gates_and_chest_clock() -> void:
	for chapter_index in range(3):
		var run = empty_run()
		run.chapter = chapter_index
		var cap := 3 + chapter_index
		while int(run.weapons.lightning.level) < cap:
			Spellbook.rank_weapon("lightning", run.weapons)
		for reward_is_treasure in [false, true]:
			var cards := Spellbook.offers(run.weapons, 8, run.speed, run.maximum_health, run.rng, "雷の魔女", run.relics, reward_is_treasure, [], chapter_index)
			var legal := true
			for card in cards:
				legal = legal and card.id != "weapon:lightning"
			expect(legal, "Chapter draft never offers a rank above the current chapter cap")
		var before: Dictionary = run.weapons.lightning.duplicate(true)
		offer_choice(run, "weapon:lightning")
		expect(not run.choose_upgrade(0) and run.weapons.lightning == before, "Stale rank cards cannot bypass the chapter cap at apply time")
		expect(run.equipment_info().rank_cap == cap and run.snapshot().rank_cap == cap, "UI and read-only snapshot receive the exact chapter rank cap")
		while int(run.weapons.lightning.level) < 5:
			Spellbook.rank_weapon("lightning", run.weapons)
		run.relics.assign(["storm_ink"])
		var treasure_cards := Spellbook.offers(run.weapons, 8, run.speed, run.maximum_health, run.rng, "雷の魔女", run.relics, true, [], chapter_index)
		var has_evolution := false
		for card in treasure_cards:
			has_evolution = has_evolution or card.kind == "evolution"
		expect(has_evolution == (chapter_index == 2), "Only a final-chapter treasure can offer a ready evolution")
		var normal_cards := Spellbook.offers(run.weapons, 8, run.speed, run.maximum_health, run.rng, "雷の魔女", run.relics, false, [], chapter_index)
		var normal_safe := true
		for card in normal_cards:
			normal_safe = normal_safe and card.kind != "evolution"
		expect(normal_safe, "A normal XP draft never contains an evolution, even in chapter three")
		offer_choice(run, "evolve:lightning")
		expect(not run.choose_upgrade(0) and not run.weapons.lightning.evolved, "A manually stale normal-level evolution is rejected before mutation")
		offer_choice(run, "evolve:lightning", true)
		expect(run.choose_upgrade(0) == (chapter_index == 2), "Evolution apply validates both final chapter and treasure source")
	var blocked = Spellbook.initial_weapons()
	while int(blocked.lightning.level) < 5:
		Spellbook.rank_weapon("lightning", blocked)
	expect(not Spellbook.evolve_weapon("lightning", blocked, ["storm_ink"]) and not Spellbook.evolve_weapon("lightning", blocked, ["storm_ink"], 2, false) and not Spellbook.evolve_weapon("lightning", blocked, ["storm_ink"], 1, true), "The content apply helper also fails closed without both progression conditions")
	var starter = empty_run()
	Spellbook.rank_weapon("lightning", starter.weapons)
	Spellbook.rank_weapon("lightning", starter.weapons)
	var fill_cards := Spellbook.offers(starter.weapons, 7, starter.speed, starter.maximum_health, starter.rng, "雷の魔女", [], false, [], 0)
	var new_spells := 0
	for card in fill_cards:
		if card.kind == "weapon" and int(starter.weapons[card.item_id].level) == 0:
			new_spells += 1
	expect(new_spells >= 2, "Capping the starter presents two different new spells instead of leaving empty slots stranded")
	var pacing = empty_run()
	var costs: Array[int] = []
	for i in range(6):
		costs.append(pacing.experience_needed)
		pacing.experience = pacing.experience_needed
		pacing.check_level_up()
		pacing.skips_left = 10
		pacing.skip_choice()
	expect(costs == [5, 9, 13, 27, 61, 115], "XP curve preserves onboarding but allocates remaining ranks across the campaign")
	var clock = empty_run()
	clock._elite_index = 2
	advance(clock, 29.95)
	expect(clock.chests.is_empty() and clock.chapter_info().chest_positions.size() == 2, "Future chest positions exist in authored data without visible unusable chests")
	clock.pause()
	advance(clock, 3.0)
	expect(clock.chests.is_empty(), "Pausing immediately before chest arrival cannot advance its spawn clock")
	clock.resume()
	advance(clock, 0.05)
	expect(clock.chests.size() == 1 and not clock.chests[0].opened and is_equal_approx(clock.chapter_elapsed, 30.0), "The first usable static chest appears on the real thirty-second boundary")
	advance(clock, 74.95)
	expect(clock.chests.size() == 1, "The second chest does not appear before its real scheduled time")
	advance(clock, 0.05)
	expect(clock.chests.size() == 2 and clock.chests[0].id != clock.chests[1].id and is_equal_approx(clock.chapter_elapsed, 105.0), "The second chest appears exactly once at 105 seconds")
	clock.player = clock.chests[1].position
	clock._update_chests()
	expect(clock.state == "treasure" and clock.chests[1].opened, "Every rendered newly spawned chest is immediately usable on contact")
	var unlock = empty_run()
	unlock.specialization = Spellbook.specialize("spec_lightning", unlock.weapons)
	Spellbook.rank_weapon("lightning", unlock.weapons)
	Spellbook.rank_weapon("lightning", unlock.weapons)
	unlock.cast(unlock._capture_payload("lightning", false), Vector2.ZERO, false)
	unlock.state = "chapter_clear"
	unlock.next_chapter()
	offer_choice(unlock, "weapon:lightning")
	expect(unlock.choose_upgrade(0) and unlock.weapons.lightning.level == 4 and is_equal_approx(unlock.weapons.lightning.damage, 30.8) and unlock.timeline.attacks.is_empty(), "Chapter unlock permits the next rank while retaining specialization and clearing the old echo")
