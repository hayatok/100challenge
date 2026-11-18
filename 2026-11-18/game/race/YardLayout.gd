extends RefCounted

# Positions are in metres. Progress p increases along world -Z.
const FINISH := 170.0
const DECK_EDGE := 4.7
const SPLIT_START := 85.0
const SPLIT_END := 140.0
const INNER_LEFT := -4.7
const INNER_RIGHT := -0.2
const GAP_START := 108.0
const GAP_END := 119.0
const OUTER_WIDTH := 3.8
const OUTER_CENTER := 2.7
const OUTER_BOW := 8.2
const CHECKPOINTS := [0.0, 39.0, 83.0, 141.0]

const BELTS := [
	{"x": 0.1, "p": 24.0, "width": 5.0, "length": 8.0, "speed": -1.55},
	{"x": -2.25, "p": 99.0, "width": 3.4, "length": 5.5, "speed": -1.15},
]
const ROOFS := [
	{"p": 60.0, "length": 8.0, "width": 3.0, "height": 0.92,
		"center": -0.45, "amplitude": 2.6, "omega": 0.93, "phase": 0.4},
	{"p": 113.75, "length": 8.0, "width": 2.9, "height": 0.55,
		"center": -2.65, "amplitude": 1.95, "omega": 0.95, "phase": -0.6},
]


static func outer_x(p: float) -> float:
	var fraction := clampf((p - SPLIT_START) / (SPLIT_END - SPLIT_START), 0.0, 1.0)
	return OUTER_CENTER + OUTER_BOW * sin(PI * fraction)


static func on_outer(x: float, p: float) -> bool:
	return p >= SPLIT_START and p < SPLIT_END and absf(x - outer_x(p)) <= OUTER_WIDTH * 0.5


static func outer_slope(p: float) -> float:
	var frequency := PI / (SPLIT_END - SPLIT_START)
	return OUTER_BOW * frequency * cos(frequency * (p - SPLIT_START))


static func ground_height(x: float, p: float) -> float:
	if p < SPLIT_START or p >= SPLIT_END:
		return 0.0 if absf(x) <= DECK_EDGE else -INF
	if on_outer(x, p):
		return 0.0
	if x >= INNER_LEFT and x <= INNER_RIGHT and (p < GAP_START or p >= GAP_END):
		return 0.0
	return -INF


static func roof_x(index: int, time: float) -> float:
	var roof: Dictionary = ROOFS[index]
	return roof.center + roof.amplitude * sin(roof.omega * time + roof.phase)


static func roof_at(x: float, p: float, time: float) -> int:
	for index in ROOFS.size():
		var roof: Dictionary = ROOFS[index]
		if absf(p - roof.p) <= roof.length * 0.5 and absf(x - roof_x(index, time)) <= roof.width * 0.5:
			return index
	return -1


static func belt_speed(x: float, p: float) -> float:
	for belt: Dictionary in BELTS:
		if absf(p - belt.p) <= belt.length * 0.5 and absf(x - belt.x) <= belt.width * 0.5:
			return belt.speed
	return 0.0
