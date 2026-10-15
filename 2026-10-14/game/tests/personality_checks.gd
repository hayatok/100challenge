extends RefCounted
## Actual actor geometry and clocks; staged unit checks are not a playthrough.

const Colleague := preload("res://scripts/colleague.gd")
var _failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	_failures.clear()
	var stage := Node3D.new()
	tree.root.add_child(stage)
	var mug := Colleague.new()
	var stamp := Colleague.new()
	stage.add_child(mug)
	stage.add_child(stamp)
	mug.build("Personality_00")
	stamp.build("Personality_01", "stamp")
	await tree.process_frame
	mug.set_process(false)
	stamp.set_process(false)
	_expect(mug.debug_snapshot()["role"] == "mug" and mug.debug_snapshot()["mug_visible"],
		"Default actor API preserves the cat-mug personality")
	_expect(stamp.debug_snapshot()["role"] == "stamp" and not stamp.debug_snapshot()["mug_visible"]
		and stamp.find_child("StampHand", true, false) != null
		and stamp.find_child("ApprovalPaper", true, false) != null,
		"Supervisor replaces the whole mug arm with a real stamp hand and desk paper")
	for actor in [mug, stamp]:
		_expect(actor.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"Personality art adds no bodies or colliders")
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			_expect(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"Personality art adds no shadows")
		_expect(actor.react(Vector3(2, 0, -3), 1, 0.05) == "accepted", "Fresh personality reaction is accepted")
		actor._process(0.23)
	var mug_pose: Dictionary = mug.debug_snapshot()
	var lift_pose: Dictionary = stamp.debug_snapshot()
	_expect(float(mug_pose["mug_lift"]) > 0.1 and int(mug_pose["stamps"]) == 0,
		"Mug personality lifts and protects its mug without stamping")
	_expect(float(lift_pose["stamp_lift"]) > 0.1 and not lift_pose["stamp_contact"]
		and not lift_pose["approval_visible"] and int(lift_pose["stamps"]) == 0,
		"Supervisor first raises the stamp, before paper contact or approval")
	stamp._process(0.37)
	var contact: Dictionary = stamp.debug_snapshot()
	_expect(contact["stamp_contact"] and contact["approval_visible"] and contact["ink_visible"]
		and contact["callout_text"] == "承認！" and int(contact["stamps"]) == 1,
		"Downstroke contacts the paper once and reveals red ink and approval")
	_expect(_point(contact["stamp_base_position"]).distance_to(_point(contact["paper_position"])) < 0.015,
		"Stamp rubber physically reaches the paper on the desk")
	_expect(is_zero_approx(float(contact["mug_lift"])) and contact["expression"] == "startled",
		"Stamp personality retains its startled face without a mug gesture")
	_expect(stamp.react(Vector3(-2, 0, -2), 2, 0.05) == "upgraded", "Stronger event upgrades supervisor")
	var upgrade: Dictionary = stamp.debug_snapshot()
	_expect(upgrade["elapsed"] == contact["elapsed"] and upgrade["stamps"] == 1
		and upgrade["starts"] == 1 and upgrade["upgrades"] == 1,
		"Supervisor upgrade keeps onset, pose clock and single contact intact")
	stamp._process(1.0)
	mug._process(1.5)
	_expect(_returned(stamp.debug_snapshot()) and _returned(mug.debug_snapshot()),
		"Both personalities return to sleepy poses and clear transient art")
	_expect(stamp.react(Vector3.ZERO, 1, 0.05) == "suppressed", "Supervisor retains individual cooldown")
	stamp.reset_reaction()
	stamp.set_feedback_quality("控えめ")
	stamp.react(Vector3(2, 0, -3), 1, 0.05)
	stamp._process(0.23)
	var subdued: Dictionary = stamp.debug_snapshot()
	_expect(float(subdued["stamp_lift"]) > 0.05 and float(subdued["stamp_lift"]) < float(lift_pose["stamp_lift"]),
		"Subdued supervisor keeps a legible, smaller real downstroke")
	stamp._process(0.37)
	var subdued_contact: Dictionary = stamp.debug_snapshot()
	_expect(subdued_contact["stamp_contact"] and subdued_contact["approval_visible"]
		and subdued_contact["callout_text"] == "承認！" and subdued_contact["expression"] == "startled",
		"Subdued preserves stamp contact, face and full Japanese approval")
	stamp.set_process(true)
	tree.paused = true
	var paused := stamp.debug_snapshot()
	await tree.process_frame
	await tree.process_frame
	_expect(stamp.debug_snapshot() == paused, "SceneTree pause freezes active stamp, ink, approval and cooldown")
	tree.paused = false
	await tree.process_frame
	await tree.process_frame
	_expect(stamp.debug_snapshot() != paused, "Unpausing resumes the actual stamp clock")
	stamp.reset_reaction()
	stamp.react(Vector3.ZERO, 1, 0.26)
	tree.paused = true
	var waiting := stamp.debug_snapshot()
	await tree.process_frame
	await tree.process_frame
	_expect(stamp.debug_snapshot() == waiting, "SceneTree pause also freezes supervisor onset delay")
	stamp.reset_reaction()
	var reset: Dictionary = stamp.debug_snapshot()
	_expect(_returned(reset) and reset["stamps"] == 0 and reset["starts"] == 0
		and reset["upgrades"] == 0 and reset["elapsed"] == 0.0
		and reset["stamp_clock"] == 0.0 and reset["cooldown"] == 0.0,
		"Retry reset clears pending/paused stamp counters, clocks and all reaction art")
	tree.paused = false
	stage.queue_free()
	await tree.process_frame
	return _failures.duplicate()

func _point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _returned(snapshot: Dictionary) -> bool:
	return snapshot["state"] == "sleepy" and snapshot["expression"] == "sleepy" \
		and not snapshot["callout"] and not snapshot["approval_visible"] \
		and not snapshot["stamp_contact"] and not snapshot["ink_visible"] \
		and is_zero_approx(float(snapshot["stamp_lift"])) \
		and is_zero_approx(float(snapshot["mug_lift"]))

func _expect(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)
