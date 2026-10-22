extends SceneTree

const Run = preload("res://scripts/run_model.gd")
const Main = preload("res://scripts/main.gd")
const Interface = preload("res://scripts/interface.gd")
const Profile = preload("res://scripts/profile.gd")
const Spellbook = preload("res://scripts/spellbook.gd")
var failures: Array[String] = []
var checks := 0
var reroll_requests := 0
var run = Run.new()
var interface
var profile = Profile.new()
var root_control: Control

class SnapshotAudioStub:
	extends RefCounted
	var music_start_count := 2
	var music_started := true
	var music := {"stream_paused": false}

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func _settle() -> void:
	interface.refresh()
	await process_frame
	await process_frame

func _text_content(node: Node) -> String:
	var content := ""
	for child in node.get_children():
		if child is Label or child is Button:
			content += str(child.text) + "\n"
		content += _text_content(child)
	return content

func _verify_page(label: String) -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for node in interface.overlay.find_children("*", "Control", true, false):
		if node is Button:
			_check(rect.encloses(node.get_global_rect()), label + ": button stays within viewport: " + node.text)
			_check(node.size.y >= 44, label + ": minimum button hit area")
		if node is Label and node.has_meta("layout_bounds"):
			var bounds: Rect2 = node.get_meta("layout_bounds")
			_check(node.size.x <= bounds.size.x + 1.0, label + ": text stays within assigned width: " + node.text.replace("\n", " / ").left(55))
			_check(node.get_minimum_size().y <= bounds.size.y + 2.0 and node.size.y <= bounds.size.y + 2.0, label + ": text fits assigned height: " + node.text.replace("\n", " / ").left(55) + " [actual %.1f, min %.1f, target %.1f]" % [node.size.y, node.get_minimum_size().y, bounds.size.y])
	_check(is_instance_valid(interface._default_focus) and not interface._default_focus.disabled, label + ": actionable default keyboard focus")

func _verify_hud(label: String) -> void:
	for node in interface.hud.find_children("*", "Label", true, false):
		if node.is_visible_in_tree() and node.has_meta("layout_bounds"):
			var bounds: Rect2 = node.get_meta("layout_bounds")
			_check(node.size.x <= bounds.size.x + 1.0, label + ": HUD text stays within assigned width: " + node.text.replace("\n", " / ").left(55))
			_check(node.get_minimum_size().y <= bounds.size.y + 2.0 and node.size.y <= bounds.size.y + 2.0, label + ": HUD text fits assigned height: " + node.text.replace("\n", " / ").left(55))

func _run() -> void:
	var probe := Main.new()
	var perf: Dictionary = probe._performance_snapshot()
	var encoded := JSON.stringify(perf)
	var decoded = JSON.parse_string(encoded)
	_check(decoded is Dictionary and decoded.size() == 9, "performance counters serialize as a JSON object with the existing and added fields")
	for key in ["fps", "effects", "projectiles", "objects", "resources", "nodes", "orphans", "static_bytes", "static_peak_bytes"]:
		var value = decoded.get(key)
		_check((value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0, "performance JSON counter is numeric and nonnegative: " + key)
	probe.interface = Interface.new()
	probe.soundscape = SnapshotAudioStub.new()
	var payload: Dictionary = probe._snapshot_payload()
	var payload_json = JSON.parse_string(JSON.stringify(payload))
	for key in ["state", "chapter", "choices", "upgrade_choices", "arena", "perf", "settings", "profile", "gui", "audio"]:
		_check(payload_json.has(key), "snapshot payload preserves public field: " + key)
	_check(payload_json.upgrade_choices == payload_json.choices and payload_json.audio.music_starts == 2, "snapshot keeps choice alias and audio metadata")
	_check(payload_json.settings == probe.profile.settings() and payload_json.gui.starter == "lightning", "snapshot keeps profile settings and GUI metadata")
	probe._publish_snapshot()
	_check(probe._snapshot_publisher == null and not probe._initialize_snapshot_bridge(), "native publication never initializes the web bridge")
	_check(probe.run.state == "title" and probe.run.elapsed == 0.0, "snapshot construction and publication do not mutate native gameplay")
	probe.interface.free()
	probe.free()
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(root_control)
	interface = Interface.new()
	interface.run = run
	interface.profile = profile
	root_control.add_child(interface)
	interface.reroll_requested.connect(func() -> void: reroll_requests += 1)
	await _settle()
	_verify_page("title")
	_check(not interface.hud.visible, "title keeps combat HUD hidden")
	_check(interface.handle_shortcut(KEY_C), "keyboard opens codex")
	await _settle()
	_check(interface.local_screen == "codex" and run.state == "title", "codex does not start a run")
	_check(not _text_content(interface.overlay).contains("鬼火"), "unseen magic name remains hidden")
	_verify_page("codex")
	_check(interface.handle_shortcut(KEY_ESCAPE) and interface.local_screen.is_empty(), "Escape closes codex")
	for screen in ["starters", "settings", "storage"]:
		interface.open_screen(screen)
		await _settle()
		_verify_page(screen)
		interface.close_screen()
	interface.open_screen("settings")
	interface.open_screen("storage")
	interface.close_screen()
	_check(interface.local_screen == "settings", "Back returns to the nested settings page")
	interface.close_screen()
	profile.load_document("{invalid")
	interface.open_screen("storage")
	await _settle()
	_verify_page("invalid storage")
	_check(_text_content(interface.overlay).contains("退避"), "invalid record recovery is visible and explicit")
	interface.close_screen()
	profile = Profile.new()
	interface.profile = profile
	run.reset(true, 101, "moon")
	await _settle()
	_verify_hud("combat")
	_check(not interface.boss_frame.visible and not interface.boss_panel.is_visible_in_tree(), "ordinary battle hides the entire boss frame")
	run.pause()
	await _settle()
	_verify_page("pause")
	_check(_text_content(interface.overlay).contains("第3章の宝箱"), "pause loadout explains the evolution treasure gate")
	var clock: float = run.elapsed
	interface.open_screen("settings")
	run.tick(3.0, Vector2.RIGHT)
	_check(run.elapsed == clock, "settings opened during pause cannot advance combat")
	interface.close_screen()
	for id in ["lightning", "thorn"]:
		Spellbook.rank_weapon(id, run.weapons)
	for id in ["moon", "lightning", "thorn"]:
		while int(run.weapons[id].level) < 5:
			Spellbook.rank_weapon(id, run.weapons)
	run.relics.assign(["storm_ink", "moonstone", "thorn_seed"])
	run.choices.assign([Spellbook.offer("weapon:wisp", run.weapons), Spellbook.offer("relic:lantern_oil", run.weapons), Spellbook.offer("evolve:moon", run.weapons)])
	for card in run.choices:
		card.full_slots = str(card.id) != "evolve:moon"
	run.state = "upgrade"
	await _settle()
	_verify_page("upgrade")
	_check(_text_content(interface.overlay).contains("今章はRank%dまで" % int(run.equipment_info().get("rank_cap", 5))), "upgrade states the current chapter rank cap")
	_check(_text_content(interface.overlay).contains("第3章の宝箱"), "upgrade evolution condition names the third chapter treasure")
	_check(interface.handle_shortcut(KEY_R) and reroll_requests == 1, "ordinary upgrade supports the R shortcut")
	run._begin_replacement(run.choices[0])
	await _settle()
	_verify_page("weapon replacement")
	run.cancel_replacement()
	run._begin_replacement(run.choices[1])
	await _settle()
	_verify_page("relic replacement")
	run.cancel_replacement()
	run.choices.assign([Spellbook.offer("spec_lightning", run.weapons), Spellbook.offer("spec_moon", run.weapons), Spellbook.offer("spec_echo", run.weapons)])
	await _settle()
	_verify_page("specialization")
	var spec_reroll: Button = interface.overlay.find_child("RerollButton", true, false)
	_check(spec_reroll.disabled and spec_reroll.text.contains("専門化"), "specialization disables reroll and explains why")
	var requests_before := reroll_requests
	_check(interface.handle_shortcut(KEY_R) and reroll_requests == requests_before, "specialization R shortcut cannot emit an unavailable action")
	run.state = "treasure"
	await _settle()
	_verify_page("treasure")
	run.state = "chapter_clear"
	run.chapter_clears.assign([0])
	profile.record_run(run.snapshot(), false)
	await _settle()
	_verify_page("chapter map")
	run.damage_received = {"contact": 42.0, "projectile": 24.0, "hazard": 34.0}
	run.damage_taken = 100.0
	run.last_damage_cause = "boss_thorn"
	for state in ["paused", "defeat", "victory"]:
		run.state = state
		await _settle()
		_verify_page(state)
		if state in ["defeat", "victory"]:
			var equipment_before: Dictionary = run.equipment_info()
			interface.open_screen("loadout")
			await _settle()
			_verify_page("finished loadout " + state)
			_check(_text_content(interface.overlay).contains("静電のインク") and _text_content(interface.overlay).contains("Rank 5"), "results retain final relics and weapon ranks")
			interface.handle_shortcut(KEY_ESCAPE)
			await _settle()
			_check(run.state == state and run.equipment_info() == equipment_before, "Back from finished loadout preserves result and equipment")
	for category in ["weapons", "relics", "enemies", "evolutions"]:
		profile.data.discoveries[category] = (Spellbook.WEAPON_IDS if category in ["weapons", "evolutions"] else (Spellbook.RELIC_IDS if category == "relics" else Spellbook.ENEMY_IDS)).duplicate()
		interface.codex_category = category
		interface.open_screen("codex")
		await _settle()
		_verify_page("discovered " + category)
		if category == "evolutions":
			_check(_text_content(interface.overlay).contains("第3章の宝箱"), "discovered evolution codex explains the treasure gate")
		interface.close_screen()
	interface.large_text = true
	interface._build_hud()
	for state in ["title", "paused", "upgrade", "chapter_clear", "defeat"]:
		run.state = state
		interface.last_screen = ""
		await _settle()
		_verify_page("large text " + state)
	interface.open_screen("loadout")
	await _settle()
	_verify_page("large text finished loadout")
	interface.close_screen()
	run.state = "playing"
	await _settle()
	_verify_hud("large text combat")
	run.choices.assign([Spellbook.offer("weapon:wisp", run.weapons), Spellbook.offer("relic:lantern_oil", run.weapons), Spellbook.offer("evolve:moon", run.weapons)])
	for card in run.choices:
		card.full_slots = str(card.id) != "evolve:moon"
	run.state = "upgrade"
	await _settle()
	_verify_page("large text full equipment")
	run._begin_replacement(run.choices[1])
	await _settle()
	_verify_page("large text relic replacement")
	run.cancel_replacement()
	run.state = "paused"
	interface.open_screen("settings")
	await _settle()
	_verify_page("large text settings")
	interface.close_screen()
	interface.codex_category = "evolutions"
	interface.open_screen("codex")
	await _settle()
	_verify_page("large text evolution codex")
	root_control.queue_free()
	await process_frame
	print("GUI tests: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
