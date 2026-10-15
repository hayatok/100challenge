extends RefCounted
## Exercise the actual five employees and real office destruction contract.

const Office := preload("res://scripts/office.gd")
var _failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	_failures.clear()
	var office := Office.new()
	tree.root.add_child(office)
	office.build()
	await tree.process_frame
	var people: Array = office.get("_colleagues")
	for person in people:
		person.set_process(false)
	_expect(people.size() == 5, "Reactions retain exactly the five authored coworkers")
	for person in people:
		_expect(person.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Employees add no physics bodies or collisions")
		_expect(person.find_child("Head_Geometry", true, false) != null,
			"Static batching leaves authored coworker motion groups intact")
	var contact := Vector3(-0.9, 0, 32)
	var broken := office.try_break(contact, 6.0)
	var first := office.react_to_breaks(broken, contact, 6.0)
	var waiting := office.debug_feedback_snapshot()
	_expect(first["accepted"] == 1 and first["selected"] == 1,
		"Actual introductory destruction wakes only the nearby employee")
	_expect(_state_count(waiting, "waiting") == 1 and _state_count(waiting, "sleepy") == 4,
		"Four farther employees keep their sleepy reference pose")
	_expect(float(waiting["coworkers"][0]["delay"]) >= 0.05
		and float(waiting["coworkers"][0]["delay"]) <= 0.26,
		"Distance-based reaction onset remains within a short bounded delay")
	_advance(people, 0.4)
	var normal: Dictionary = office.debug_feedback_snapshot()["coworkers"][0]
	var normal_mug := float(normal["mug_lift"])
	_expect(normal["expression"] == "startled" and normal["callout"],
		"Nearby accepted break changes the face and shows its own spatial callout")
	_expect(Vector3(normal["impact"][0], normal["impact"][1], normal["impact"][2]).is_equal_approx(contact),
		"Employee looks at the actual nearest destroyed prop")
	var source_direction: Vector3 = contact - people[0].global_position
	var expected_yaw := atan2(-source_direction.x, -source_direction.z)
	_expect(is_equal_approx(float(normal["target_yaw"]), expected_yaw)
		and absf(float(normal["chair_yaw"])) > 0.1 and normal_mug > 0.1,
		"Chair turns toward the destruction while the cat mug rises")
	_expect(int(normal["visible_meshes"]) <= 6, "Reaction stays within six visible meshes including chair and indicator")
	var upgrade := office.react_to_breaks([_event("upgrade", contact, 100000)], contact, 6.0)
	var stronger: Dictionary = office.debug_feedback_snapshot()["coworkers"][0]
	_expect(upgrade["upgraded"] == 1 and stronger["strength"] == 2
		and stronger["starts"] == normal["starts"] and stronger["elapsed"] == normal["elapsed"],
		"A stronger fresh break upgrades the existing pose without restarting it")
	_expect(stronger["mug_lift"] > normal_mug and stronger["upgrades"] == 1,
		"A stronger impact materially increases mug protection")
	var weak := office.react_to_breaks([_event("weak", contact, 10000)], contact, 5.0)
	_expect(weak["suppressed"] == 1, "Small repeated destruction cannot replay an active response")
	_expect(office.react_to_breaks(broken, contact, 9.0)["selected"] == 0,
		"The same reward IDs cannot replay or upgrade")
	_advance(people, 1.7)
	var recovered: Dictionary = office.debug_feedback_snapshot()["coworkers"][0]
	_expect(recovered["state"] == "sleepy" and not recovered["callout"]
		and is_zero_approx(float(recovered["chair_yaw"])) and is_zero_approx(float(recovered["mug_lift"])),
		"Response returns the chair, sleepy face, mug and callout to their reference pose")
	_expect(office.react_to_breaks([_event("cooldown", contact, 100000)], contact, 9.0)["suppressed"] == 1,
		"Individual cooldown also prevents another onset after the visible pose ends")
	_advance(people, 1.0)
	_expect(office.react_to_breaks(broken, contact, 9.0)["selected"] == 0,
		"Old reward IDs remain spent after cooldown")
	office.reset_props()
	_expect(_all_reset(office.debug_feedback_snapshot()), "Retry resets all clocks, expressions, poses, labels and event IDs")
	var scattered: Array[Dictionary] = []
	for i in range(people.size()):
		scattered.append(_event("cap_%s" % i, people[i].global_position, 100000))
	var capped := office.react_to_breaks(scattered, contact, 8.0)
	_expect(capped["accepted"] == 2 and capped["selected"] == 2,
		"Even a wide simultaneous batch selects at most two nearest employees")
	_expect(_state_count(office.debug_feedback_snapshot(), "sleepy") == 3,
		"The remaining employees stay sleepy during a multi-impact batch")
	var overflow := office.react_to_breaks([_event("overflow", people[4].global_position, 100000)], contact, 8.0)
	_expect(overflow["accepted"] == 0 and _state_count(office.debug_feedback_snapshot(), "sleepy") == 3,
		"Fresh nearby events cannot accumulate more than two simultaneous responses")
	_expect(not JSON.stringify(office.debug_feedback_snapshot()).is_empty(),
		"Reaction diagnostics contain JSON-safe data")
	office.reset_props()
	_expect(office.react_to_breaks([_event("far", Vector3(0, 0, -100), 100000)], contact, 12.0)["selected"] == 0,
		"A distant break cannot wake employees just because the player is nearby")
	office.set_feedback_quality("控えめ")
	office.react_to_breaks([_event("subdued", contact, 10000)], contact, 5.0)
	_advance(people, 0.4)
	var subdued: Dictionary = office.debug_feedback_snapshot()["coworkers"][0]
	_expect(subdued["expression"] == "startled" and subdued["callout"]
		and float(subdued["mug_lift"]) < normal_mug * 0.25
		and is_equal_approx(float(subdued["target_yaw"]), expected_yaw),
		"Subdued feedback preserves gaze, expression and static ! with reduced motion")
	office.reset_props()
	office.set_feedback_quality("派手")
	office.react_to_breaks([_event("pause", contact, 10000)], contact, 5.0)
	for person in people:
		person.set_process(true)
	tree.paused = true
	var paused := office.debug_feedback_snapshot()
	await tree.process_frame
	await tree.process_frame
	_expect(office.debug_feedback_snapshot() == paused,
		"Pausing freezes onset delay, pose clock and cooldown together")
	tree.paused = false
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame
	_expect(office.debug_feedback_snapshot() != paused, "Unpausing resumes employee clocks")
	office.reset_props()
	_expect(_all_reset(office.debug_feedback_snapshot()), "Reset also clears a waiting or paused onset")
	office.queue_free()
	await tree.process_frame
	return _failures.duplicate()

func _event(id: String, at: Vector3, base: int) -> Dictionary:
	return {"id": id, "position": at, "base": base}

func _advance(people: Array, seconds: float) -> void:
	for person in people:
		person._process(seconds)

func _state_count(snapshot: Dictionary, state: String) -> int:
	var count := 0
	for person in snapshot["coworkers"]:
		if person["state"] == state:
			count += 1
	return count

func _all_reset(snapshot: Dictionary) -> bool:
	if snapshot["seen_events"] != 0:
		return false
	for person in snapshot["coworkers"]:
		if person["state"] != "sleepy" or person["callout"] or person["elapsed"] != 0.0 \
			or person["cooldown"] != 0.0 or person["starts"] != 0 \
			or person["expression"] != "sleepy" or person["chair_yaw"] != 0.0 \
			or person["mug_lift"] != 0.0:
			return false
	return true

func _expect(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)
