extends SceneTree
## Native, deliberately arranged UI composition fixtures, separate from real Web play.
## Run with a native display; headless test runs cannot capture rendered pixels.

const Run := preload("res://scripts/run_model.gd")
const Garden := preload("res://scripts/garden_view.gd")
const Interface := preload("res://scripts/interface.gd")
const Profile := preload("res://scripts/profile.gd")
const Spellbook := preload("res://scripts/spellbook.gd")
var model = Run.new()
var profile = Profile.new("user://echo-witch-design-fixture-%d.json" % OS.get_process_id())
var view
var ui
var out := ""
var checks := 0
var failed := false
var captures: Array[Dictionary] = []

class BlockedProfile:
	extends "res://scripts/profile.gd"
	func _read_storage() -> Dictionary:
		return {"ok": false}
	func _write_storage(_raw: String) -> Dictionary:
		return {"ok": false}

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Design fixtures require the native renderer; headless mode cannot produce these screenshots")
		quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	out = OS.get_environment("DESIGN_RENDER_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("res://../.cache/design/native")
	DirAccess.make_dir_recursive_absolute(out)
	call_deferred("_run")

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("FAIL: " + label)

func settle() -> void:
	view.refresh()
	ui.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String, dimensions: Vector2i = Vector2i(1280, 720)) -> void:
	await settle()
	var image: Image = root.get_texture().get_image()
	expect(image.get_width() == dimensions.x and image.get_height() == dimensions.y, "native fixture dimensions: " + name)
	expect(image.save_png(out.path_join(name + ".png")) == OK, "native fixture PNG saved: " + name)
	captures.append({"name": name, "width": image.get_width(), "height": image.get_height(), "state": model.state, "page": ui.local_screen, "large_text": ui.large_text, "controls": ui.control_snapshot()})

func capture_artificial_event(name: String, event: Dictionary) -> void:
	# Arrange a presentation record after normal view synchronization. Nothing here
	# advances combat or adds a production state-changing browser interface.
	view.last_signature.clear()
	await settle()
	view.presentation.events.assign([event])
	view.queue_redraw()
	await capture(name)
	captures.back()["artificial_event_fixture"] = name
	captures.back()["artificial_events"] = [event.duplicate(true)]
	captures.back()["boss_hud_present"] = not model.boss_data().is_empty()
	expect(view.presentation.events.size() == 1, "artificial fixture contains exactly one notification event: " + name)

func artificial_event(kind: String, at: Vector2, extras: Dictionary = {}) -> Dictionary:
	var event := {"kind": kind, "position": at, "age": 0.24, "duration": 1.2, "echo": false, "seed": 197, "priority": 4, "serial": 1}
	event.merge(extras, true)
	return event

func fill_loadout() -> void:
	for id in ["lightning", "thorn"]:
		Spellbook.rank_weapon(id, model.weapons)
	for id in ["moon", "lightning", "thorn"]:
		while int(model.weapons[id].level) < 5:
			Spellbook.rank_weapon(id, model.weapons)
	model.relics.assign(["storm_ink", "moonstone", "thorn_seed"])

func long_choices() -> void:
	model.choices.assign([Spellbook.offer("weapon:wisp", model.weapons), Spellbook.offer("relic:lantern_oil", model.weapons), Spellbook.offer("evolve:moon", model.weapons)])
	for card in model.choices:
		card.full_slots = str(card.id) != "evolve:moon"

func _run() -> void:
	print("DESIGN_NATIVE: arranged native fixtures only; these are not real gameplay or browser QA")
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1280, 720)
	model.reset(false, 197, "moon")
	view = Garden.new()
	view.run = model
	root.add_child(view)
	ui = Interface.new()
	ui.run = model
	ui.profile = profile
	root.add_child(ui)
	await capture("01-title")
	ui.open_screen("starters")
	await capture("02-starters")
	ui.close_screen()
	model.reset(true, 197, "moon")
	fill_loadout()
	model.elapsed = 98.25
	model.chapter_elapsed = 98.25
	model.health = 64
	model.level = 12
	model.kills = 438
	model.experience = 97
	model.experience_needed = 143
	model.resonance_hits = 84
	model.echo_active = true
	model.echo = Vector2(-140, 75)
	model.enemies.clear()
	var kinds := ["hound", "charger", "archer", "bat", "sentinel", "wisp"]
	var points := [Vector2(-360,-120), Vector2(-190,-210), Vector2(160,-190), Vector2(350,-80), Vector2(290,145), Vector2(-300,155)]
	for index in range(kinds.size()):
		var enemy: Dictionary = model.spawn_enemy(kinds[index], points[index])
		enemy.phase = "seek"
		enemy.timer = 0.0
	await capture("03-hud-combat")
	model.state = "upgrade"
	long_choices()
	await capture("04-long-three-choices")
	model._begin_replacement(model.choices[0])
	await capture("05-weapon-replacement")
	model.cancel_replacement()
	model._begin_replacement(model.choices[1])
	await capture("06-relic-replacement")
	model.cancel_replacement()
	model.state = "treasure"
	await capture("07-treasure")
	model.state = "chapter_clear"
	model.chapter_clears.assign([0])
	profile.record_run(model.snapshot(), false)
	await capture("08-chapter-clear")
	model.damage_summary = {"player": 34800.0, "echo": 21375.0, "resonance": 11712.0, "poison": 2480.0, "by_weapon": {}}
	model.damage_received = {"contact": 42.0, "projectile": 24.0, "hazard": 34.0}
	model.damage_taken = 100.0
	model.last_damage_cause = "boss_thorn"
	model.chapter = 2
	model.chapter_clears.assign([0, 1, 2])
	model.elapsed = 655.75
	model.kills = 2478
	model.level = 31
	model.state = "victory"
	profile.record_run(model.snapshot(), false)
	await capture("09-victory")
	ui.open_screen("loadout")
	await capture("10-result-loadout")
	ui.close_screen()
	model.state = "defeat"
	model.health = 0
	await capture("11-defeat")
	model.state = "paused"
	model.health = 64
	await capture("12-paused")
	ui.open_screen("settings")
	await capture("13-settings")
	ui.close_screen()
	for category in ["weapons", "relics", "enemies", "evolutions"]:
		profile.data.discoveries[category] = (Spellbook.WEAPON_IDS if category in ["weapons", "evolutions"] else (Spellbook.RELIC_IDS if category == "relics" else Spellbook.ENEMY_IDS)).duplicate()
		ui.codex_category = category
		ui.codex_index = 0
		ui.open_screen("codex")
		await capture("14-codex-" + category)
		ui.close_screen()
	var blocked := BlockedProfile.new("user://echo-witch-design-blocked-%d.json" % OS.get_process_id())
	blocked.data = profile.data.duplicate(true)
	blocked.load_profile()
	ui.profile = blocked
	ui.open_screen("storage")
	await capture("15-storage-failed")
	ui.close_screen()
	ui.profile = profile
	profile.load_document("{invalid")
	ui.open_screen("storage")
	await capture("16-storage-invalid")
	ui.close_screen()
	profile = Profile.new("user://echo-witch-design-fixture-%d.json" % OS.get_process_id())
	ui.profile = profile
	root.size = Vector2i(960, 540)
	await capture("17-paused-960", Vector2i(960, 540))
	ui.large_text = true
	ui._build_hud()
	ui.last_screen = ""
	await capture("18-paused-large-960", Vector2i(960, 540))
	root.size = Vector2i(1280, 720)
	model.state = "upgrade"
	long_choices()
	await capture("19-long-choices-large")
	# These four additional images deliberately isolate the manuscript notification
	# against the actual combat/boss HUD. The existing 22 captures stay unchanged.
	ui.large_text = false
	ui._build_hud()
	ui.last_screen = ""
	model.reset(true, 197, "moon")
	model.enemies.clear()
	model.effects.clear()
	model.pickups.clear()
	await capture_artificial_event("20-artificial-chapter-start", artificial_event("chapter", model.player, {"chapter": 0, "clear": false}))
	model.chapter_stage = "boss"
	model.chapter_elapsed = 180.0
	var boss: Dictionary = model.spawn_enemy(str(model.chapter_info().boss_id), Vector2(225, -10))
	boss.phase = "arrival"
	boss.timer = 1.65
	var boss_fields := {"actor": "enemy", "id": int(boss.id), "actor_kind": str(boss.kind), "boss_kind": str(boss.kind), "boss": true, "phase": 1, "chapter": int(model.chapter), "name": str(model.chapter_info().boss_name)}
	await capture_artificial_event("21-artificial-boss-arrival", artificial_event("boss_arrival", boss.position, boss_fields))
	boss.phase = "seek"
	boss.timer = 0.0
	boss.phase_index = 2
	boss.hp = float(boss.max_hp) * 0.45
	boss_fields.phase = 2
	await capture_artificial_event("22-artificial-boss-second-phase", artificial_event("boss_phase", boss.position, boss_fields))
	await capture_artificial_event("23-artificial-evolution-with-boss-hud", artificial_event("evolution", model.player, {"weapon": "moon"}))
	var manifest := FileAccess.open(out.path_join("fixtures.json"), FileAccess.WRITE)
	expect(manifest != null, "native fixture manifest opens")
	if manifest != null:
		manifest.store_string(JSON.stringify({"kind": "artificial native UI composition fixtures", "real_gameplay": false, "profile_path": profile.path, "checks": checks, "failed": failed, "captures": captures}, "\t"))
		manifest.close()
	print("DESIGN_NATIVE: %d checks, %d arranged frames, failed=%s, out=%s" % [checks, captures.size(), failed, out])
	ui.free()
	view.free()
	await process_frame
	quit(1 if failed else 0)
