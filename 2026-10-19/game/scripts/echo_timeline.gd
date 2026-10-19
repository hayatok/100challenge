extends RefCounted
## Only simulation time enters this history. Pausing cannot age a pending echo.

const DELAY := 2.0
var positions: Array[Dictionary] = []
var attacks: Array[Dictionary] = []

func reset(position: Vector2) -> void:
	positions = [{"time": 0.0, "position": position}]
	attacks.clear()

func record_position(at: float, position: Vector2) -> void:
	positions.append({"time": at, "position": position})
	while positions.size() > 2 and float(positions[1].time) < at - DELAY - 0.15:
		positions.pop_front()

func position_at(at: float) -> Vector2:
	if positions.is_empty():
		return Vector2.ZERO
	if at <= float(positions[0].time):
		return positions[0].position
	for i in range(1, positions.size()):
		if float(positions[i].time) >= at:
			var previous: Dictionary = positions[i - 1]
			var current: Dictionary = positions[i]
			var span := float(current.time) - float(previous.time)
			var weight := clampf((at - float(previous.time)) / maxf(span, 0.000001), 0.0, 1.0)
			return (previous.position as Vector2).lerp(current.position, weight)
	return positions.back().position

func record_attack(at: float, payload: Dictionary) -> void:
	attacks.append({"time": at, "payload": payload.duplicate(true)})

func consume_attacks(at: float) -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	while not attacks.is_empty() and float(attacks[0].time) + DELAY <= at + 0.000001:
		ready.append(attacks.pop_front().payload)
	return ready
