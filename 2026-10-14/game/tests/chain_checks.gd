extends RefCounted
## Finite causal contacts in the actual authored office, independently of particles.

const Office := preload("res://scripts/office.gd")
const Rules := preload("res://scripts/rules.gd")
var _failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	_failures.clear()
	var office := Office.new()
	tree.root.add_child(office)
	office.build()
	await tree.process_frame
	var rules := Rules.new()
	rules.begin()
	var contact := Vector3(-0.9, 0, 32)
	var first := office.try_break(contact, 6.0, Vector3.FORWARD)
	_expect(first.size() == 1 and first[0]["kind"] == "wagon" and first[0]["depth"] == 0,
		"Direct impact begins with only the contacted wagon")
	rules.register_breaks(first)
	_expect(office.debug_destruction_snapshot()["pending"] == 1,
		"Wagon reserves exactly one future contact")
	_expect(office.try_break(Vector3(1.4, 0, 30.2), 9.0).is_empty(),
		"Chair cannot double-award a prop reserved by the moving wagon")
	_expect(office.advance_destruction(0.34).is_empty(), "Tower waits for visible wagon contact")
	var tower := office.advance_destruction(0.01)
	_expect(tower.size() == 1 and tower[0]["kind"] == "tower" and tower[0]["depth"] == 1
		and tower[0]["source_id"] == first[0]["id"], "After 0.35s the wagon, not the chair, breaks the tower")
	rules.advance(0.35)
	rules.register_breaks(tower)
	var box := office.advance_destruction(0.35)
	_expect(box.size() == 1 and box[0]["kind"] == "box" and box[0]["depth"] == 2
		and box[0]["source_id"] == tower[0]["id"] and box[0]["chain_root"] == first[0]["id"],
		"Falling tower causes the third, final paper-box contact")
	rules.advance(0.35)
	rules.register_breaks(box)
	_expect(rules.damage == 230000 and rules.combo == 3 and rules.rush_timer > 0.0,
		"The real three prop values use existing x1/x2/x3 scoring and start one rush")
	_expect(office.advance_destruction(10.0).is_empty() and office.try_break(contact, 9.0).is_empty(),
		"Spent props and floor remnants cannot recurse or score again")
	_expect(office.debug_destruction_snapshot()["history"].size() == 3,
		"One direct collision has exactly three bounded causal events")
	office.reset_props()
	var reset := office.debug_destruction_snapshot()
	_expect(reset["clock"] == 0.0 and reset["pending"] == 0 and reset["history"].is_empty(),
		"Retry clears propagation clock, reservations and history")
	for prop in reset["props"]:
		_expect(not prop["broken"] and not prop["reserved"] and prop["visual"]["intact_visible"]
			and not prop["visual"]["settled_visible"], "Retry restores every intact prop in the same frame")
	office.try_break(contact, 9.0, Vector3.BACK)
	_expect(office.advance_destruction(1.0).is_empty(), "Backward impacts do not send a forward chain")
	office.reset_props()
	office.try_break(contact, 2.5)
	_expect(office.advance_destruction(1.0).is_empty(), "A gentle contact cannot launch a wagon chain")
	office.reset_props()
	office.try_break(contact, 6.0)
	tree.paused = true
	var paused := office.debug_destruction_snapshot()
	_expect(office.advance_destruction(0.5).is_empty() and office.try_break(Vector3(1.4, 0, 30.2), 9.0).is_empty(),
		"Paused office accepts neither elapsed propagation nor direct contacts")
	await tree.process_frame
	_expect(office.debug_destruction_snapshot() == paused, "Pause freezes real collapse children and reservations")
	tree.paused = false
	var due := office.advance_destruction(0.35)
	_expect(due.size() == 1 and due[0]["kind"] == "tower", "Resume continues the pending next contact")
	office.stop_propagation()
	var end := rules.finish()
	_expect(office.advance_destruction(5.0).is_empty() and office.debug_destruction_snapshot()["pending"] == 0
		and rules.register_breaks(box).is_empty() and rules.damage == end["damage"],
		"Goal cancels outstanding contacts and the finished score cannot change")
	office.reset_props()
	office.set_feedback_quality("控えめ")
	var subdued := office.try_break(contact, 6.0)
	subdued.append_array(office.advance_destruction(0.35))
	subdued.append_array(office.advance_destruction(0.35))
	_expect(subdued.size() == 3 and subdued[0]["kind"] == "wagon" and subdued[1]["kind"] == "tower"
		and subdued[2]["kind"] == "box", "Reduced motion retains identical contact order and conditions")
	_expect(not JSON.stringify(office.debug_feedback_snapshot()).is_empty(), "Causal diagnostics are JSON-safe")
	office.free()
	return _failures.duplicate()

func _expect(value: bool, description: String) -> void:
	if not value:
		_failures.append(description)
